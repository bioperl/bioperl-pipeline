#
# Interface for running programs
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
# 
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME
Bio::Pipeline::RunnableI;

=head1 SYNOPSIS
#Do not run this module directly.
=head1 DESCRIPTION
This provides a standard BioPerl Pipeline Runnable interface that should be
implemented by any object that wants to be treated as a Runnable. This
serves purely as an abstract base class for implementers and can not
be instantiated.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org                         - General discussion
  http://bio.perl.org/MailList.html             - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via email
or the web:

  bioperl-bugs@bio.perl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - Shawn Hoon 

Email: shawnh@fugu-sg.org 

=head1 CONTRIBUTORS


=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut



package Bio::Pipeline::RunnableI;

use vars qw(@ISA);
use strict;


use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);

=head1 ABSTRACT METHODS

These methods need to be implemented in any
module which implements

<Bio::Pipeline::RunnableI>.

This methods will be used by RunnableDB so they MUST be
implemeted to work properly.

=head2 datatypes
  my %datatype = $self->datatypes();

  Returns a hash of datatypes that describes the parameters
  keyed by the runnable routines that is called to set them.
  For example if there is a $runnable->seq function which takes
  in a Bio::Seq object, then one of the entries in the hash will
  be 
  $datatype{seq}=Bio::Pipeline::Datatype=>(-object_type=>'Bio::Seq',
                                           -name=>'sequence',
                                           -reftype=>'SCALAR);

  This is used by RunnableDB to match the inputs provided with the inputs
  required by the runnable and calling the set methods accordingly. 

=head2 params
  $self->params("-C 10 -W 3")
  
  This is a get/set method to allow any string of parameters to be
  passed into the runnable without needing a explicit get/set method

=head2 parse_results

  $self->parse_results()

  This is called by the runnable itself to parse the results from
  the program output


=head2 run

    $self->run();

Actually runs the analysis programs.  If the
analysis has fails, it should throw an
exception.  It should also remove any temporary
files created (before throwing the exception!).

=head2 output

    @output = $self->output();

Return a list of objects created by the analysis
=cut


sub datatypes {
  my ($self) = @_;
  return;
}
sub run {
  my ($self) = @_;
  return;
}
sub params {
  my ($self) = @_;
  return;
}
sub parse_results {
  my ($self) = @_;
  return;
}
sub output {
  my ($self) = @_;
  return;
}

1;
