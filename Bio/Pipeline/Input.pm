#
# BioPerl module for Bio::Pipeline::IO
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
=head1 NAME
Bio::Pipeline::IO input/output object for pipeline

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
  my ($name,$inputDBA,$dbobj) = $self->_rearrange([qw(  NAME
                                                        INPUT_DBA
                                                        )],@args);

  $name || $self->throw("Need an input name");
  $inputDBA|| $self->throw("Need an input_dba");

  $self->name($name);
  $self->input_dba($inputDBA);
  
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

  return $self->input_dba->fetch_input($self->name);
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

=head2 input_dba

  Title    : input_dba
  Function : 
  Example  : 
  Returns  : 
  Args     : 

=cut

sub input_dba{
    my ($self,$inputDBA) = @_;
    if (defined $inputDBA) {
        $self->{'_input_dba'} = $inputDBA;
    }
    return $self->{'_input_dba'};
}

1;



    
          
