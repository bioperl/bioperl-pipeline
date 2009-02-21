#
# BioPerl module for Bio::Pipeline::Input
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
Bio::Pipeline::Input input object


=head1 SYNOPSIS

   my $input = Bio::Pipeline::Input->new(-name=>"sequence1",
                                         -tag=>"sequence",
                                         -input_handler=>$iohandler,
                                         -dynamic_arguments=>"-length 10",
                                         -job_id=>1);
  my $input = $io->fetch_input();

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
  http://bugzilla.open-bio.org/

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
  Usage   : my $input = Bio::Pipeline::Input->new(-name=>"sequence1",
                                                  -tag=>"sequence", 
                                                  -input_handler=>$iohandler,
                                                  -dynamic_arguments=>"-length 10",
                                                  -job_id=>1);
  Function: Constructor for the input
  Returns : L<Bio::Pipeline::Input>
  Args    : name  the key id of the input used to fetch it
            tag   the tag of the input, used to set runnable get/set
            input_handler the iohandler used to fetch this input
            dynamic_arguments dynamic arguments generated on the fly used to fetch this input
            job_id  the job id that this input belongs to

=cut

sub new {
  my($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($name,$tag,$input_handler,$dyn_arg,$job_id,$dbID) = $self->_rearrange([qw(    NAME
                                                                TAG
                                                                INPUT_HANDLER
                                                                DYNAMIC_ARGUMENTS
                                                                JOB_ID
                                                                DBID)],@args);

  $name || $self->throw("Need an input name");

  #allow direct variable, string to be fed.
  $input_handler && $self->input_handler($input_handler);
  $self->job_id($job_id) if defined $job_id;
  $self->tag($tag);
  $self->name($name);
  $self->dynamic_arguments($dyn_arg);
  $self->dbID($dbID) if $dbID;
  return $self;
}    


=head2 fetch

  Title    : fetch
  Function : fetch the input object that this input represents if
             there is an input_handler, if not, just return the name
  Example  : $input->fetch
  Returns  : 
  Args     : 

=cut

sub fetch{
  my ($self,$notransformer) = @_;
  if(!$self->input_handler) {
      return $self->name;
  }
  else {
    return $self->input_handler->fetch_input($self,$notransformer);
  }
}


=head1 Member variable access

These methods let you get at and set the member variables

=head2 name

  Title    : name
  Function : get/set for input name
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
  Function : get/set for input tag
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
  Function : get/set for dynamic_arguments
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
  Function : get/set for input_handler
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
  Function : get/set for job_id
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
  Function : get/set for the adaptor of this input
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
  Function : get/set for the dbID of this input
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



    
          
