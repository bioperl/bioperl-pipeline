#
# BioPerl module for Bio::Pipeline::Input
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
=head1 NAME
Bio::Pipeline::Input input object

=head1 SYNOPSIS
my $io = Bio::Pipeline::IO->new(-dbadaptor=>$dbadaptor,
                                -dataadaptor=>$data_adaptor,
                                -dataadaptormethod=>$data_adaptor_method);
my $input = $io->fetch_input("Scaffold_1.1");

=head1 DESCRIPTION

The input/output object for reading input and writing output.

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

package Bio::Pipeline::Input;
use vars qw(@ISA);
use strict;

use Bio::Root::Root;
@ISA = qw(Bio::Root::Root);

=head2 new

  Title   : new
  Usage   : 
  Function: 
  Returns : 
  Args    : 
=cut

sub new {
  my($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($name,$tag,$input_handler,$dyn_arg,$job_id) = $self->_rearrange([qw(    NAME
                                                                TAG
                                                                INPUT_HANDLER
                                                                DYNAMIC_ARGUMENTS
                                                                JOB_ID)],@args);

  $name || $self->throw("Need an input name");

  #allow direct variable, string to be fed.
  #$input_handler || $self->throw("Need an input_handler attached to this input.");
  $input_handler && $self->input_handler($input_handler);
  $self->job_id($job_id) if defined $job_id;
  $self->tag($tag);
  $self->name($name);
  $self->dynamic_arguments($dyn_arg);
  
  return $self;
}    


=head2 fetch

  Title    : fetch
  Function : 
  Example  : 
  Returns  : 
  Args     : 

=cut

sub fetch{
  my ($self) = @_;
  if(!$self->input_handler) {
      return $self->name;
  }
  else {
    return $self->input_handler->fetch_input($self);
  }
}


=head1 Member variable access

These methods let you get at and set the member variables

=head2 name

  Title    : name
  Function : 
  Example  : 
  Returns  : 
  Args     : 

=cut
 
sub name{
    my ($self,$name) = @_;
    if (defined $name) {
        $self->{'_name'} = $name;
    }
    return $self->{'_name'};
}

=head2 tag 

  Title    : tag 
  Function :
  Example  :
  Returns  :
  Args     :

=cut

sub tag{
    my ($self,$tag) = @_;
    if (defined $tag) {
        $self->{'_tag'} = $tag;
    }
    return $self->{'_tag'};
}


=head2 dynamic_arguments

  Title    : dynamic_arguments
  Function :
  Example  :
  Returns  :
  Args     :

=cut

sub dynamic_arguments{
    my ($self,$dynamic_arguments) = @_;
    if (defined $dynamic_arguments) {
        $self->{'_dynamic_arguments'} = $dynamic_arguments;
    }
    return $self->{'_dynamic_arguments'};
}


=head2 input_handler

  Title    : input_handler
  Function : 
  Example  : 
  Returns  : 
  Args     : 

=cut

sub input_handler{
    my ($self,$input_handler) = @_;
    if (defined $input_handler) {
        $self->{'_input_handler'} = $input_handler;
    }
    return $self->{'_input_handler'};
}

=head2 job_id

  Title    : job_id
  Function : 
  Example  : 
  Returns  : 
  Args     : 

=cut

sub job_id{
    my ($self,$job_id) = @_;
    if (defined $job_id) {
        $self->{'_job_id'} = $job_id;
    }
    return $self->{'_job_id'};
}

=head2 adaptor

  Title    : adaptor
  Function : 
  Example  : 
  Returns  : 
  Args     : 

=cut

sub adaptor{
    my ($self,$adaptor) = @_;
    if (defined $adaptor) {
        $self->{'_adaptor'} = $adaptor;
    }
    return $self->{'_adaptor'};
}

=head2 dbID


  Title    : dbID
  Function : 
  Example  : 
  Returns  : 
  Args     : 

=cut

sub dbID{
    my ($self,$dbID) = @_;
    if (defined $dbID) {
        $self->{'_dbID'} = $dbID;
    }
    return $self->{'_dbID'};
}

1;



    
          
