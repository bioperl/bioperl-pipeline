#
# BioPerl module for Bio::Pipeline::Dumper
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME
Bio::Pipeline::Dumper

Object for dumping output from pipeline to flat files

=head1 SYNOPSIS

  use Bio::Pipeline::Dumper;
  use Bio::SearchIO;

  my $dumper = Bio::Pipeline::Dumper->new(-module=>'BlastScore',
                                        -file=>">shawn.out",
                                        -significance=>"<0.001",
                                        -query_frac_identical=>">0.21");

  my $searchio = Bio::SearchIO->new ('-format' => 'blast',
                                     '-file'   => "blast.report");

  my @hit;
  while (my $r = $searchio->next_result){
    while(my $hit = $r->next_hit){
      push @hit, $hit;
    }
  }

  $dumper->dump(@hit);

=head1 DESCRIPTION

This is the interface by which data can be dumped into flat files.
Specific dumpers are found in Bio::Pipeline::Dumper::*

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org          - General discussion
  http://bio.perl.org/MailList.html             - About the mailing lists

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

package Bio::Pipeline::Dumper;
use vars qw(@ISA);
use strict;
use Bio::Root::Root;
use Bio::Root::IO;
use Fcntl ':flock';

@ISA = qw(Bio::Root::Root Bio::Root::IO);

=head2 new

  Title   : new
  Usage   : my $inc = Bio::Pipeline::Dumper->new('-module'=>$module,-file=>$out_file_name,-arg1=>$arg1,-arg2=>$arg2);
  Function: constructor for Dumper object 
  Returns : a new Dumper object
  Args    : -module the list of Dumper modules found in Bio::Pipeline::Dumper::*
            -file   the output file for dumping 
            -args   Any number of arguments to be passed on to the Dumper modules
=cut

sub new {
    my ($caller ,@args) = @_;
     my $class = ref($caller) || $caller;

    # or do we want to call SUPER on an object if $caller is an
    # object?
    if( $class =~ /Bio::Pipeline::Dumper::(\S+)/ ) {
      my ($self) = $class->SUPER::new(@args);
      $self->_initialize(@args);
      return $self;
    }
    else {
      my %param = @args;
      @param{ map { lc $_ } keys %param } = values %param; # lowercase keys
      my $module= $param{'-module'};
      $module || Bio::Root::Root->throw("Must you must provided a Dumper module found in Bio::Pipeline::Dumper::*");
      my $file= $param{'-file'};
      $file || Bio::Root::Root->throw("You must provide an output file ");


      $module = "\L$module";  # normalize capitalization to lower case
      return undef unless ($class->_load_Dumper_module($module));
      my ($self) =  "Bio::Pipeline::Dumper::$module"->new(@args);
      $self->module($module);
      my $sem = $file.".lck";
      $sem=~s/>//g;
      $self->_semaphore($sem);
      $self->_file($file);
      return $self;
    }
}

sub _initialize {
    my($self, @args) = @_;

    # initialize the IO part for only
    $self->_initialize_io(@args);
}

sub _semaphore {
    my ($self,$semaphore) = @_;
    if($semaphore){
        $self->{'_semaphore'} = $semaphore;
    }
    return $self->{'_semaphore'};
}

sub _file {
    my ($self,$file) = @_;
    if($file) {
        $self->{'_file'} = $file;
    }
    return $self->{'_file'};
}
=head2 _load_Dumper_module

  Title   : _load_Dumper_module
  Usage   : $inc->_load_Dumper_module("setup_genewise");
  Function: loads the input create module 
  Returns : a new Dumper object
  Args    : module, the name of the module found in Bio::Pipeline::Dumper

=cut

sub _load_Dumper_module {
    my ($self, $module) = @_;
    $module = "Bio::Pipeline::Dumper::" . $module;
    my $ok;

    eval {
      $ok = $self->_load_module($module);
    };
    if ($@) {
    print STDERR <<END;
$self: $module cannot be found
Exception $@
For more information about the Bio::Pipeline::Dumper system please see the pipeline docs 
This includes ways of checking for formats at compile time, not run time
END
  ;
  }
  return $ok;
}

=head2 module

  Title   : module
  Usage   : $inc->module
  Function: get set method for the module that the Dumper module takes
  Returns :
  Args    :

=cut

sub module {
  my ($self,$module) = @_;

  if($module){
    $self->{'_module'} = $module;
  }
  return $self->{'_module'};
}

=head2 file

  Title   : file
  Usage   : $inc->file
  Function: get set method for the file that the Dumper module writes to 
  Returns :
  Args    :

=cut

sub file {
  my ($self,$file) = @_;

  if($file){
    $self->{'_file'} = $file;
  }
  return $self->{'_file'};
}

=head2 dump 

  Title   : dump 
  Usage   : $self->run();
  Function: abstract method for running the module 
  Returns :
  Args    :

=cut

sub dump{
  my ($self) = @_;
  $self->throw_not_implemented();
}

=head2 _lock 

  Title   : _lock 
  Usage   : $self->lock($FH);
  Function: locks a file handle 
  Returns :
  Args    : a FileHandle

=cut

sub _lock {
  my ($self) = @_;

  my $dir= $self->_semaphore;
  mkdir $dir, 0777 or die "Can't make lock directory";
  my %db;
  dbmopen %db, "$dir/db", 0666;
    $db{'started'} = time();
    $db{'user'}    = getlogin();
  dbmclose %db;
}

=head2 _unlock

  Title   : _unlock
  Usage   : $self->_lock($FH);
  Function: unlocks a file handle
  Returns :
  Args    : a FileHandle

=cut

sub _unlock {
  my ($self) = @_;
  my $dir = $self->_semaphore;
  unlink "$dir/db.pag";
  unlink "$dir/db.dir";
  unlink "$dir/db.db";
  unlink "$dir/db";
  rmdir $dir;
}

sub _print {
    my ($self) = shift;

    my $fh = $self->_fh;
    while(-e $self->_semaphore){
    }
    $self->_lock($fh);
    print $fh @_;
    $self->_unlock($fh);
}
1;
