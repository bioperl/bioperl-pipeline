#
# BioPerl module for Bio::Pipeline::Utils::Dumper
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

Bio::Pipeline::Utils::Dumper

Object for dumping output from pipeline to flat files

=head1 SYNOPSIS

  use Bio::Pipeline::Utils::Dumper;
  use Bio::SearchIO;

  my $dumper = Bio::Pipeline::Utils::Dumper->new(-module=>'BlastScore',
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

#or 
  use Bio::TreeIO;
  use Bio::Pipeline::Utils::Dumper;

  my $tio = Bio::TreeIO->new(-file=>$ARGV[0],-format=>"newick");

  while(my $tree =$tio->next_tree){
    push @tree, $tree;
  }

  my $du = Bio::Pipeline::Utils::Dumper->new(-module=>"generic",
                                      -format=>"newick",
                                      -dir=>"/usr/users/shawnh/src/bioperl-pipeline/Bio/Pipeline/Dumper",
                                      -file_suffix=>".tr",
                                      -prefix=>"tree");

  #dumps to file tree.tr
  $du->dump(\@tree);




=head1 DESCRIPTION

This is the interface by which data can be dumped into flat files.
Specific dumpers are found in Bio::Pipeline::Utils::Dumper::*

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

package Bio::Pipeline::Utils::Dumper;
use vars qw(@ISA);
use strict;
use Bio::Root::Root;
use Bio::Root::IO;

@ISA = qw(Bio::Root::Root Bio::Root::IO);

=head2 new

  Title   : new
  Usage   : my $inc = Bio::Pipeline::Utils::Dumper->new('-module'=>$module,-file=>$out_file_name,-arg1=>$arg1,-arg2=>$arg2);
  Function: constructor for Dumper object 
  Returns : a new Dumper object
  Args    : -module the list of Dumper modules found in Bio::Pipeline::Utils::Dumper::*
            -file   the output file for dumping 
            -args   Any number of arguments to be passed on to the Dumper modules

=cut

sub new {
    my ($caller ,@args) = @_;
     my $class = ref($caller) || $caller;

    # or do we want to call SUPER on an object if $caller is an
    # object?
    if( $class =~ /Bio::Pipeline::Utils::Dumper::(\S+)/ ) {
      my ($self) = $class->SUPER::new(@args);
      return $self;
    }
    else {
      my %param = @args;
      @param{ map { lc $_ } keys %param } = values %param; # lowercase keys
      my $module= $param{'-module'};
      $module || Bio::Root::Root->throw("Must you must provided a Dumper module found in Bio::Pipeline::Utils::Dumper::*");
      my $file= $param{'-file'};
      delete $param{'-file'};
      my $dir = $param{'-dir'};
      delete $param{'-dir'};
      my $prefix = $param{'-prefix'};
      delete $param{'-prefix'};
      my $file_suffix = $param{'-file_suffix'};
      delete $param{'-file_suffix'};
      $file || $dir || Bio::Root::Root->throw("You must provide an output file ");

      $module = "\L$module";  # normalize capitalization to lower case
      return undef unless ($class->_load_Dumper_module($module));
      my ($self) =  "Bio::Pipeline::Utils::Dumper::$module"->new(@args);
      $self->module($module);
      $file = shift @{$file} if ref($file) eq "ARRAY";
      $self->_file($file) if $file;

      if($dir && (!-e $dir)){
         mkdir($dir,0755) || $self->warn("$dir: $!");
      }
      $self->_dir($dir) if $dir;

      $prefix = shift @{$prefix} if ref($prefix) eq "ARRAY";
      $self->_file($file) if $file;
      $self->_prefix($prefix) if $prefix;
      $self->_file_suffix($file_suffix) if $file_suffix;

      @args = %param;
      $self->_initialize(@args);
      return $self;
    }
}

sub _initialize {
    my($self, @args) = @_;  
    my $file = $self->_file;
    if(!$file && $self->_dir && $self->_prefix){
      ($file) = (split /\//, $self->_prefix)[-1]; #get the filename only
      $file = ">".$self->_dir."/$file";
      $file.=".".$self->_file_suffix if $self->_file_suffix;
    }
    # initialize the IO part for only
    $self->_initialize_io(-file=>$file);
}

sub _file {
    my ($self,$file) = @_;
    if($file) {
        $self->{'_file'} = $file;
    }
    return $self->{'_file'};
}

sub _dir {
    my ($self,$dir) = @_;
    if($dir) {
        $self->{'_dir'} = $dir;
    }
    return $self->{'_dir'};
}

sub _prefix {
    my ($self,$prefix) = @_;
    if($prefix) {
        $self->{'_prefix'} = $prefix;
    }
    return $self->{'_prefix'};
}

sub _file_suffix {
    my ($self,$suffix) = @_;
    if($suffix) {
        $self->{'_file_suffix'} = $suffix;
    }
    return $self->{'_file_suffix'};
}

=head2 _load_Dumper_module

  Title   : _load_Dumper_module
  Usage   : $inc->_load_Dumper_module("setup_genewise");
  Function: loads the input create module 
  Returns : a new Dumper object
  Args    : module, the name of the module found in Bio::Pipeline::Utils::Dumper

=cut

sub _load_Dumper_module {
    my ($self, $module) = @_;
    $module = "Bio::Pipeline::Utils::Dumper::" . $module;
    my $ok;

    eval {
      $ok = $self->_load_module($module);
    };
    if ($@) {
    print STDERR <<END;
$self: $module cannot be found
Exception $@
For more information about the Bio::Pipeline::Utils::Dumper system please see the pipeline docs 
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

sub _print {
    my ($self,$string) = @_;
    my $fh = $self->_fh;
    print $fh $string,"\n";
    $fh->flush;
}
1;
