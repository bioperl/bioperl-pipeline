# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
# Copyright Shawn Hoon
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
# =pod
#
# =head1 NAME
#
# Bio::Pipeline::Runnable::EnsemblRunnable
#
=head1 SYNOPSIS

  use Bio::Pipeline::Runnable::EnsemblRunnable;
  use Bio::SeqIO;


  my $seqio = Bio::SeqIO->new(-file=>$ARGV[0]);
  my $seq = $seqio->next_seq;
  my $database = "/data0/tmp_family/Fugu_rubripes.pep.fa";

  my $runner = Bio::Pipeline::Runnable::EnsemblRunnable->new(-module=>"Blast",
                                                           -query=>$seq,
                                                           -program=>'blastp',
                                                           -database=>$database,
                                                           -threshold=>'1e-6');

  my @output = $runner->run;

=head1 DESCRIPTION

The runnable that enables biopipe to run Ensembl runnables.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-pipeline@bioperl.org          - General discussion
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
  http://bugzilla.open-bio.org/

=head1 AUTHOR - FuguI Team

Email fugui@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::Runnable::EnsemblRunnable;
use vars qw(@ISA $AUTOLOAD);
use strict;
use Bio::Root::Root;
use Bio::Pipeline::DataType;
use Bio::Pipeline::RunnableI;

@ISA = qw(Bio::Pipeline::RunnableI);

=head2 new

 Title   :   new
 Usage   :   $self->new()
 Function:   return a new EnsemblRunnable wrapper
 Returns :   L<Bio::Pipeline::Runnable::EnsemblRunnable>
 Args    :   -module the specific Ensembl Runnable to use
             Any other parameters  that are passed to the 
             Ensembl Runnable.

=cut

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($module) = $self->_rearrange([qw(MODULE)],@args);
  $module && $self->module($module);
  

  my %param = @args;
  @param{ map { lc $_ } keys %param } = values %param; # lowercase keys

 
  foreach my $method (keys %param){
      my $copy = $method;
      $copy=~s/-//g;
      $self->$copy($param{$method});
  }
  return $self;
}


=head2 add_tag

 Title   :   add_tag
 Usage   :   $self->add_tag()
 Function:   add to the list of methods that EnsemblRunnable expects
             this is to accomodate for some required parameters
             in the new method of the specific EnsemblRunnable
 Returns :   Array of strings 
 Args    :

=cut

sub add_tag{
    my ($self,$tag) = @_;
    if($tag){
      push @{$self->{'_tag'}}, $tag;
    }

    return @{$self->{'_tag'}};
}

=head2 get_tags

 Title   :   get_tags
 Usage   :   $self->get_tags()
 Function:   gets the list of tags 
 Returns :   Array of strings
 Args    :

=cut

sub get_tags {
    my ($self) = @_;
    return @{$self->{'_tag'}};
}


=head2 AUTOLOAD

 Title   :   AUTOLOAD
 Usage   :   
 Function:   Allow any get/sets
 Returns :
 Args    :

=cut

sub AUTOLOAD {
    my $self = shift;
    my $val = shift;

    my $tag= $AUTOLOAD;
    $tag=~ s/.*:://;
    if($tag && $val){
        $self->add_tag($tag);
        $self->{$tag} = $val;
    }
    return $self->{$tag};
}

=head2 get_input_params

 Title   :   get_input_params
 Usage   :   $self->get_input_params()
 Function:   returns an array of tag-value parameters 
 Returns :   Array of tag-value pairs
 Args    :

=cut

sub get_input_params {
    my ($self) = @_;
    my @param;
    foreach my $tag ($self->get_tags){
        
        push @param, ("-".$tag,$self->$tag);
    }
    return @param;
}

=head2 module

 Title   :   module
 Usage   :   $self->module()
 Function:   get/set for module, the name of the name of the ensembl runnable
             to use e.g Blast, Genscan, RepeatMasker etc
 Returns :
 Args    :

=cut

sub module {
  my ($self,$mod) = @_; 
  if($mod){
    $self->{'_module'} = $mod;
  }
  return $self->{'_module'};
}

=head2 run

 Title   :   run
 Usage   :   $self->run()
 Function:   execute 
 Returns :   
 Args    :

=cut

sub run {
  my ($self) = @_;
  my $module = $self->module;
  my @params;
  if($self->analysis && $self->analysis->parameters){
    @params = $self->parse_params($self->analysis->parameters);
  }
  push @params, $self->get_input_params();
  my $runnable = $self->load_runnable($self->module,@params);
  
  $runnable->run;
  my @output = $runnable->output;
  $self->output(\@output);
  return $self->output;
}

=head2 runnable

 Title   :   runnable
 Usage   :   $self->runnable()
 Function:   get/set for runnable 
 Returns :
 Args    :

=cut

sub runnable {
    my ($self) = @_;
    if(!defined $self->{'_runnable'}){
        $self->load_runnable($self->module,@_);
    }
    return $self->{'_runnable'};
}

=head2 load_runnable

 Title   :   load_runnable
 Usage   :   $self->load_runnable($module)
 Function:   loads the ensembl runnable 
 Returns :
 Args    :

=cut

sub load_runnable {
  my($self) = shift;
  my $module = shift;

  if(! defined $self->{'_runnable'}){
    my $namespace = "Bio/EnsEMBL/Pipeline/Runnable/$module";
    require "$namespace.pm";
    $namespace=~s/\//\::/g;
    $self->{"_runnable"} = (${namespace}->new(@_));
  }
    return $self->{"_runnable"};
}
1;
