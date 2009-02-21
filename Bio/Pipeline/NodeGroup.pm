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

Bio:: - Desc

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
package Bio::Pipeline::NodeGroup;

use Bio::Root::Root;

use vars qw(@ISA);
use strict;

@ISA = qw( Bio::Root::Root);

sub new {
  my ($class, @args) = @_;
    my $self = bless {},$class;
      
    my ($id,$name,$description,$nodes)	= $self->_rearrange([qw(ID
                                                                                                              NAME
                                                                                                              DESCRIPTION
                                                                                                              NODES
                                                                                                              )],@args);
  defined($id) || $self->throw("Need a node id to create a node object");
  #$self->throw("Need at least 1 node per group") unless (scalar(@{$nodes} > 0));
  
  $self->id($id);
  $self->description($description);
  $self->name($name);
  $self->nodes($nodes);
  
  
  
  return $self;
  
}

sub id {
  my ($self,$id) = @_;
  if ($id) {
    $self->{'_id'} = $id;
  }
  return $self->{'_id'};
}

sub name {
  my ($self,$name) = @_;
  if($name) {
    $self->{'_name'} = $name;
  }
  return $self->{'_name'};
}

sub description{
  my ($self,$description) = @_;
  if ($description) {
    $self->{'_description'} = $description;
  }
  return $self->{'_description'};
}

sub nodes {
  my ($self,$nodes) = @_;
  if ($nodes) {
    $self->{'_nodes'} = $nodes;
  }
  return $self->{'_nodes'};
}
                                                                                           

1;


