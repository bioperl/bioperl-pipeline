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

Bio::Pipeline::SQL::NodeAdaptor

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

package Bio::Pipeline::SQL::NodeAdaptor;

use Bio::Pipeline::Node;
use Bio::Root::Root;

use vars qw(@ISA);
use strict;

@ISA = qw( Bio::Pipeline::SQL::BaseAdaptor);

# Let the code begin...
sub get_nodes_by_group_id {
  my ($self,$id) = @_;
  my $sth = $self->prepare("SELECT node_id,node_name FROM node WHERE group_id =$id");
  my $sth2 = $self->prepare("SELECT distinct(group_id) FROM node where node_id=?");
  $sth->execute();
  
  my @nodes;
  while(my ($node_id,$node_name) = $sth->fetchrow_array()){
    $sth2->execute($node_id);
    my $group_ids = $sth2->fetchrow_arrayref; #get the other groups that this node belongs to
    
    my $node = Bio::Pipeline::Node->new('-id'=>$node_id,'-name'=>$node_name,'-current_group'=>$id,'-group_id'=>$group_ids);
    push @nodes, $node;
  }
  
  return @nodes;
}

sub get_all_nodes {
  my ($self) = @_;
  my $sth = $self->prepare("SELECT node_id,node_name FROM node GROUP BY node_id");
  my $sth2 = $self->prepare("SELECT distinct(group_id) FROM node where node_id=?");
  $sth->execute();
    my @nodes;
  while(my ($node_id,$node_name) = $sth->fetchrow_array()){
    $sth2->execute($node_id);
    my $group_ids = $sth2->fetchrow_arrayref;
    
    my $node = Bio::Pipeline::Node->new('-id'=>$node_id,'-name'=>$node_name,'-current_group'=>0,'-group_id'=>$group_ids);
    push @nodes, $node;
  }
  
  return @nodes;
}


sub store {
  my ($self, $node) = @_;
  if (!defined ($node->id)) {
    my $sth = $self->prepare( qq{
      INSERT INTO node
         SET node_name= ?,
             group_id= ? } );
    $sth->execute($node->name, $node->current_group);

   $sth = $self->prepare( q{
      SELECT last_insert_id()
     } );
   $sth->execute;

   my $dbID = ($sth->fetchrow_array)[0];
   $node->id( $dbID );
  }
  else {
    my $sth = $self->prepare( qq{
      INSERT INTO node
         SET node_id= ?,
             node_name= ?,
             group_id= ? } );
    $sth->execute($node->id, $node->name, $node->current_group );
  }
  return $node->id;
}

1;
