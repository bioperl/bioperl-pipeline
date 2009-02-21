#
# BioPerl module for Bio::Pipeline::InputCreate::setup_family
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

Bio::Pipeline::Input::setup_family

=head1 SYNOPSIS

  my $inc = Bio::Pipeline::Input::setup_family->new(-contig_ioh=>$cioh,
                                                   -protein_ioh=>$pioh,
                                                   -dh_ioh     =>$dh_ioh,
                                                   -padding => 1000);
  $inc->run;

=head1 DESCRIPTION

The input/output object for reading input and writing output.

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

package Bio::Pipeline::InputCreate::setup_family;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::InputCreate;
use Bio::Pipeline::DataType;
use POSIX;
use Bio::Root::IO;

@ISA = qw(Bio::Pipeline::InputCreate);

sub _initialize {
    my ($self,@args) = @_;
    $self->SUPER::_initialize(@args);

    my ($pep_file,$chop_size,$workdir,$format_db_exe) = $self->_rearrange([qw(PEPTIDE_FILE CHOPSIZE WORKDIR FORMAT_DB_EXE)],@args);

    $pep_file|| $self->throw("Need a peptide file");
    $self->pep_file($pep_file);

    $chop_size ||= 400;
    $self->chop_size($chop_size);

    $workdir ||= '/tmp';
    $self->workdir($workdir);

    #standalone blast works with ncbi blast only anyway 
    $format_db_exe ||='formatdb';

    $self->format_db_exe($format_db_exe);


}

=head2 pep_file

  Title   : pep_file
  Usage   : $self->pep_file()
  Function: get/sets of the pep_file
  Returns :  
  Args    :

=cut

sub pep_file{
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_pep_file'} = $arg;
    }
    return $self->{'_pep_file'};
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

=head2 chop_size

  Title   : chop_size
  Usage   : $self->chop_size()
  Function: get/set number of files that pep_file is to chopped into 
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

=head2 run

  Title   : run
  Usage   : $self->run($next_anal,$input)
  Function: creates the jobs for genewise 
  Returns :
  Args    : L<Bio::Pipeline::Analysis>, Hash reference

=cut

sub run {
    my ($self,$next_anal) = @_;
    my @file_names = $self->_chop_files;
    $self->_setup_blastdb();
  #  my $count=1;
    foreach my $file(@file_names){
      my $input = $self->create_input($file,'','seq1');
      my $job   = $self->create_job($next_anal,[$input]);
      $self->dbadaptor->get_JobAdaptor->store($job);
#      last if $count >= 1;
 #     $count++;

    }
    return;
}

sub _setup_blastdb {
    my ($self) = @_;
    my $pep_file = $self->pep_file;

    Bio::Root::IO->exists_exe($self->format_db_exe) || return;
    my $cmd = $self->format_db_exe. " -p T -i ".$pep_file;
    my $status = system($cmd);
    $self->throw("Problems formatting db $pep_file $!") if $status > 0;


    return;
}

#internal method for chopping up peptide files into bitesize chunks for blasting
#taken from chopper script by Anton Enright and Philip Lijnzaad

sub _chop_files {
    my ($self) = @_;
    my $filename= $self->pep_file;
    my $workdir = $self->workdir;
    my $n_chunks = $self->chop_size;
    my @filenames;

    if($workdir){
      mkdir($workdir,0755) || $self->warn("$workdir: $!");
    }
    #chop peptide files into digestible parts
    open(FILE, $filename) || $self->throw("Cannot open $filename for chopping");
    my $total=0;
    my $sequences=0;
    my @line;
    while (<FILE>) {
      chomp($_);
      $line[$total]=$_;
      if (substr($_,0,1) eq '>') {
        $sequences++;
      }
      $total++;
    }
    $filename = (split /\//, $filename)[-1]; #get the filename only
    $self->warn("File $filename has $total lines and $sequences sequences\n");
    my $split=floor($total/$n_chunks);
    $self->warn("File will be split into $n_chunks units of approx $split lines\n");

    my $x=1;
    my $j=0;
    my $file="$workdir/$filename.$x";
    push @filenames, $file;
    open (FILEOUT,">$file") || $self->throw("$file: $!");
    for (my $i=0; $i<$total; $i++) {
      my $curr_line=$line[$i];
      $j++;
      if ( ($j > $split) && (substr($curr_line,0,1) eq '>') ) {
        $x++;
        $j=0;
        close FILEOUT;
        $file="$workdir/$filename.$x";
        push @filenames, $file;
        open (FILEOUT, "> $file") || die "$file: $!";
      }
       print FILEOUT "$curr_line\n";
    }
    close FILEOUT; 
    return @filenames;
}

1;
    



