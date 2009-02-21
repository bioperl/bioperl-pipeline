# $Id: .pm,v 1.51 Fri Jun 07 05:43:37 SGT 2002
# BioPerl module for 
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
# Copyright Shawn Hoon
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Pipeline::Node - Desc

=head1 SYNOPSIS

    $seqio  = Bio::SeqIO->new( '-format' => 'embl' , -file => 'myfile.dat');
    $seqobj = $seqio->next_seq();

=head1 DESCRIPTION

Description here.

=head1 EXAMPLES

A simple and fundamental block of code

  use Bio::SeqIO;

=head1 FEEDBACK


=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists. Your participation is much appreciated.

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

  bioperl-bugs@bioperl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - Shawn Hoon


Email shawnh@fugu-sg.org


=head1 APPENDIX


The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a "_".

=cut


# Let the code begin...
package Bio::Pipeline::Node;

use Bio::Root::Root;

use vars qw(@ISA);
use strict;

@ISA = qw( Bio::Root::Root);

sub new {
  my ($class, @args) = @_;
    my $self = bless {},$class;
    
    my ($id,$name,$curr_group,$group_id)	= $self->_rearrange([qw(ID
                                                                                           NAME
                                                                                           CURRENT_GROUP
                                                                                           GROUP_ID
                                                                                           )],@args);
  $id || $self->throw("Need a node id to create a node object");
  $group_id = defined($group_id) || [0];
  
  $self->id($id);
  $self->groups ($group_id);
  $self->name($name);
  
  $curr_group = defined($curr_group) || $group_id->[0];
  
  $self->current_group($curr_group);
  
  return $self;
  
}

sub id {
  my ($self,$id) = @_;
  if ($id) {
    $self->{'_id'} = $id;
  }
  return $self->{'_id'};
}

sub groups {
  my ($self,$groups) = @_;
  if($groups) {
    $self->{'_groups'} = $groups;
  }
  return $self->{'_groups'};
}

sub current_group {
  my ($self,$curr) = @_;
  if ($curr) {
    $self->{'_curr'} = $curr;
  }
  return $self->{'_curr'};
}

sub name {
  my ($self,$name) = @_;
  if ($name) {
    $self->{'_name'} = $name;
  }
  return $self->{'_name'};
}
                                                                                           

1;


