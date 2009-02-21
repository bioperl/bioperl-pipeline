#
# BioPerl module for Bio::Pipeline::InputCreate::setup_file
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
=head1 NAME

Bio::Pipeline::Input::setup_file

=head1 SYNOPSIS

  my $inc = Bio::Pipeline::InputCreate::setup_file->new(-runnable=>"Bio::Pipeline::Runnable::Blast",
                                                   -format=>"fasta",
                                                   -input_file=>"/data0/blast.fa",
                                                   -result_dir=>"/data/blast_results",
                                                   -chop_nbr=>1);
  $inc->run;

=head1 DESCRIPTION

This input create is a generic flat file setup module for the pipeline. It allows
files to be chopped up in to smaller pieces to be split into jobs.
Currently works with
Blast,
Clustalw
DnaBlockAligner

and in theory any files that have programs take take in sequence files


=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Support 
 
Please direct usage questions or support issues to the mailing list:
  
L<bioperl-l@bioperl.org>
  
rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via email
or the web:

  bioperl-bugs@bio.perl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - Shawn Hoon

Email shawnh@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut

package Bio::Pipeline::InputCreate::setup_file;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::InputCreate;
use Bio::Pipeline::Runnable::Blast;
use Bio::Pipeline::DataType;
use Bio::SeqIO;
use Bio::Root::IO;
use File::Copy;
use Cwd;

@ISA = qw(Bio::Pipeline::InputCreate);

sub _initialize {
    my ($self,@args) = @_;
    $self->SUPER::_initialize(@args);

    my ($runnable, 
        $informat,
        $outformat,
        $tag,
        $input_file,
        $input_dir,
        $chop_size,
        $workdir,
        $result_dir,
        $full_path,
        $format_db,
        $format_db_exe,
        $format_db_arg) = $self->_rearrange([qw(RUNNABLE 
                                                INFORMAT 
                                                OUTFORMAT
                                                TAG
                                                INPUT_FILE 
                                                INPUT_DIR
                                                CHOP_NBR 
                                                WORKDIR 
                                                RESULT_DIR 
                                                FULL_PATH
                                                FORMAT_DB  
                                                FORMAT_DB_EXE 
                                                FORMAT_DB_ARG)],@args);

    $runnable || $self->throw("Need an runnable name");
    $self->runnable($runnable);
    
    $input_dir || $input_file|| $self->throw("Need a input file or directory");
    $self->input_file($input_file) if $input_file;
    $self->input_dir($input_dir) if $input_dir;

    $informat ||='fasta';
    $self->informat($informat);

    $outformat ||='fasta';
    $self->outformat($outformat);
    
    
    $chop_size ||= 400;
    $self->chop_size($chop_size);

    $workdir ||= '/tmp';
    $self->workdir($workdir);

    $result_dir ||= Bio::Root::IO->catfile($workdir,"results");
    $self->result_dir($result_dir);
    $self->tag($tag) if $tag;
    
    $self->full_path($full_path) if $full_path;

    #standalone blast works with ncbi blast only anyway 
    $format_db_exe ||='formatdb';

    $self->format_db_exe($format_db_exe);
    $format_db_arg && $self->format_db_arg($format_db_arg);

    if($self->runnable =~/Blast/i && $format_db){
        $self->_setup_blastdb();
    }
}

=head2 input_file

  Title   : input_file
  Usage   : $self->input_file()
  Function: get/sets of the input_file
  Returns :  
  Args    :

=cut

sub input_file{
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_input_file'} = $arg;
    }
    return $self->{'_input_file'};
}

=head2 input_dir

  Title   : input_dir
  Usage   : $self->input_dir()
  Function: get/sets of the input_dir
  Returns :  
  Args    :

=cut

sub input_dir{
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_input_dir'} = $arg;
    }
    return $self->{'_input_dir'};
}

sub full_path{
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_full_path'} = $arg;
    }
    return $self->{'_full_path'};
}

sub tag {
    my ($self,$val) = @_;
    if($val){
        $self->{'_tag'} = $val;
    }
    return $self->{'_tag'};
}

=head2 informat

  Title   : informat
  Usage   : $self->informat()
  Function: get/sets of the informat
  Returns :  
  Args    :

=cut

sub informat{
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_informat'} = $arg;
    }
    return $self->{'_informat'};
}

=head2 outformat

  Title   : outformat
  Usage   : $self->outformat()
  Function: get/sets of the outformat
  Returns :  
  Args    :

=cut

sub outformat{
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_outformat'} = $arg;
    }
    return $self->{'_outformat'};
}
=head2 runnable

  Title   : runnable
  Usage   : $self->runnable()
  Function: get/sets of the runnable
  Returns :  
  Args    :

=cut

sub runnable{
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_runnable'} = $arg;
    }
    return $self->{'_runnable'};
}

=head2 format_db_exe

  Title   : format_db_exe
  Usage   : $self->format_db_exe()
  Function: get/sets of the format_db_exe
  Returns :
  Args    :

=cut

sub format_db_exe{
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_format_db_exe'} = $arg;
    }
    return $self->{'_format_db_exe'};
}

=head2 format_db_arg

  Title   : format_db_arg
  Usage   : $self->format_db_arg()
  Function: get/sets of the format_db_arg
  Returns :
  Args    :

=cut

sub format_db_arg{
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_format_db_arg'} = $arg;
    }
    return $self->{'_format_db_arg'};
}

=head2 chop_size

  Title   : chop_size
  Usage   : $self->chop_size()
  Function: get/set number of files that input_file is to chopped into 
  Returns :
  Args    :

=cut

sub chop_size {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_chop_size'} = $arg;
    }
    return $self->{'_chop_size'};
}

=head2 workdir

  Title   : workdir
  Usage   : $self->workdir()
  Function: get/set of the working dir 
  Returns :
  Args    :

=cut

sub workdir {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_workdir'} = $arg;
    }
    return $self->{'_workdir'};
}

=head2 result_dir

  Title   : result_dir
  Usage   : $self->result_dir()
  Function: get/set of the result dir 
  Returns :
  Args    :

=cut

sub result_dir {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_result_dir'} = $arg;
    }
    return $self->{'_result_dir'};
}

=head2 datatypes

  Title   : datatypes
  Usage   : $self->datatypes()
  Function: get/set of the datatypes required for this input create
  Returns :
  Args    :

=cut

sub datatypes {
    my ($self) = @_;
    return;
}

sub _get_file_from_dir {
    my ($self,) = @_;
    my $dir = $self->input_dir;
    opendir(DIR,$dir);
    my @files = grep(!/^\./,readdir(DIR));
    closedir DIR;

    my @file_fullpath = map{Bio::Root::IO->catfile($dir,$_)}@files;
    
    if($self->workdir){
        my $workdir = $self->workdir;
        if($workdir !~/^\/./){#is relative path
            #make absolute
            $workdir = Bio::Root::IO->catfile(cwd,$workdir);
        }
        mkdir($workdir,0755) || $self->warn("$workdir: $!");
        #move files to workdir
        foreach my $f(@file_fullpath){
          my $filename = (split /\//, $f)[-1]; 
          copy($f,Bio::Root::IO->catfile($workdir,$filename)) || $self->throw("Can't write to dir $workdir");
        }
    }

    if($self->full_path){
        @files = @file_fullpath;
    }

    return @files;
}
=head2 run

  Title   : run
  Usage   : $self->run($next_anal,$input)
  Function: creates the jobs for genewise 
  Returns :
  Args    : L<Bio::Pipeline::Analysis>, Hash reference

=cut

sub run {
    my ($self,$next_anal) = @_;
    my @file_names;
    if($self->input_file){
      @file_names = $self->_chop_files;
    }
    elsif($self->input_dir) {
      @file_names = $self->_get_file_from_dir;
    }
    my $runnable = $self->runnable;
    if($runnable !~/Bio::Pipeline::Runnable/){
        $runnable = "Bio::Pipeline::Runnable::".ucfirst $runnable;
    }
    $runnable =~s/\::/\//g;
    eval { 
        require "${runnable}.pm";
    };
    if($@){
        $self->throw("Problems finding $runnable in setup_file.pm");
    }
    $runnable =~s/\//\::/g;
    my $runn = "${runnable}"->new();
        
    my %dt = $runn->datatypes;
    foreach my $file(@file_names){
      my @input;
METHOD:      foreach my $method(keys %dt){
              if($self->tag){
                if($method eq $self->tag){
                  push @input ,$self->create_input($file,'',$self->tag);
                 }
                else {
                  next METHOD;
                }
              }
              else {
                push @input ,$self->create_input($file,'',$self->tag);
              }

             }
      my $job   = $self->create_job($next_anal,\@input);
      $self->dbadaptor->get_JobAdaptor->store($job);
    }
    return;
}

sub _setup_blastdb {
    my ($self) = @_;
    my $input_file = $self->input_file;
    
    -e $input_file.".phr" && return;

    Bio::Root::IO->exists_exe($self->format_db_exe) || return;
    my $cmd = $self->format_db_exe." ". $self->format_db_arg." -i ".$input_file;
    my $status = system($cmd);
    $self->throw("Problems formatting db $input_file $!") if $status > 0;


    return;
}

#internal method for chopping up peptide files into bitesize chunks for blasting
#taken from chopper script by Anton Enright and Philip Lijnzaad

sub _chop_files {
    my ($self) = @_;
    my $filename= $self->input_file;
    my $workdir = $self->workdir;
    my $resultdir = $self->result_dir;
    my $n_chunks = $self->chop_size;
    my $informat = $self->informat;
    my $outformat = $self->outformat;
    my @filenames;

    if($workdir){
      mkdir($workdir,0755) || $self->warn("$workdir: $!");
    }
    if($resultdir){
        mkdir($resultdir,0755) || $self->warn("$resultdir: $!");
    }
    #chop peptide files into digestible parts
    my $sio = Bio::SeqIO->new(-file=>$filename,-format=>$informat);

    my @seq;
    while(my $seq = $sio->next_seq){
        push @seq, $seq;
    }
    my $split = int(scalar(@seq)/$n_chunks);
    $split = scalar(@seq) if $split ==0;
   
    
NEW_FILE:
    my $index = 1;
    $filename = (split /\//, $filename)[-1]; #get the filename only
    my $file = Bio::Root::IO->catfile($workdir,"$filename.$index");
    if($self->full_path){
      push @filenames, "$file";
    }
    else {
      push @filenames, "$filename.$index";
    }
    $sio = Bio::SeqIO->new(-file=>">$file",-format=>$outformat);
    my $count = 0;
    while ($index <= $n_chunks){
        if($count == $split) {
            $index == $n_chunks && last;
            $count=0;
            $index++;
            $file = "$workdir/$filename.$index";
            $sio->close;
            $sio = Bio::SeqIO->new(-file=>">$file",-format=>$outformat);
            if($self->full_path){
              push @filenames, "$file";
            }
            else {
              push @filenames, "$filename.$index";
            }
        }
        my $seq = shift @seq;
        $sio->write_seq($seq);
        last if $#seq < 0; #no more seq
        $count++;
    }
    #write out the remaining ones to last file
    while($#seq >= 0){
        $sio->write_seq(shift @seq);
    }
    $sio->close();
    return @filenames;
}


sub _setup_blastdb {
    my ($self) = @_;
    my $input_file = $self->input_file;
    
    -e $input_file.".phr" && return;

    Bio::Root::IO->exists_exe($self->format_db_exe) || return;
    my $cmd = $self->format_db_exe." ". $self->format_db_arg." -i ".$input_file;
    my $status = system($cmd);
    $self->throw("Problems formatting db $input_file $!") if $status > 0;


    return;
}

1;
    



