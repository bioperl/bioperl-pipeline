# $Id: .pm,v 1.51 Fri Jun 07 05:43:37 SGT 2002
# BioPerl module for 
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
# Copyright Shawn Hoon
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Pipeline::SQL::DataMonger

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

  bioperl-l@bioperl.org              - General discussion
  http://bio.perl.org/MailList.html  - About the mailing lists

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

package Bio::Pipeline::SQL::DataMongerAdaptor;

use Bio::Pipeline::Node;
use Bio::Pipeline::Runnable::DataMonger;
use Bio::Root::Root;
use Bio::Pipeline::Filter;
use Bio::Pipeline::InputCreate;
use Bio::Pipeline::SQL::AnalysisAdaptor;

use vars qw(@ISA);
use strict;

@ISA = qw( Bio::Pipeline::SQL::BaseAdaptor);

# Let the code begin...
sub fetch_by_analysis{
    my ($self,$anal) = @_;
    #my $id = $anal->data_monger_id;
    my $id = $anal->dbID;

    #fetch filters
    my $sth = $self->prepare("SELECT filter_id,module,rank FROM filter where data_monger_id=?");
    my $sth2 = $self->prepare("SELECT tag,value FROM filter_argument WHERE filter_id=?"); 
  
    $sth->execute($id);
    
    my $dm = Bio::Pipeline::Runnable::DataMonger->new();

    while(my ($filter_id,$module,$rank) = $sth->fetchrow_array()){
        $sth2->execute($filter_id);
        my @args;
        push @args,('-module'=>$module,'-rank'=>$rank);

        while(my($tag,$value) = $sth2->fetchrow_array()){
            push @args, ($tag => $value);
        }
        my $filter = Bio::Pipeline::Filter->new(@args);
        $dm->add_filter($filter);
    }

    #fetch create inputs
    $sth = $self->prepare("SELECT input_create_id,module,rank FROM input_create where data_monger_id=?");
    $sth2 = $self->prepare("SELECT tag,value FROM input_create_argument WHERE input_create_id=?");

    $sth->execute($id);

    while(my ($inc_id,$module,$rank) = $sth->fetchrow_array()){
        $sth2->execute($inc_id);
        my @args;
        push @args,('-module'=>$module,'-rank'=>$rank,'-dbadaptor'=>$self->db);

        while(my($tag,$value) = $sth2->fetchrow_array()){
            push @args, ($tag => $value);
        }
        my $inc = Bio::Pipeline::InputCreate->new(@args);
        $dm->add_input_create($inc);
    }

    return $dm;

}


sub store {

    my ($self, $dm, $anal_id) = @_;


#    my $dm_analysis = Bio::Pipeline::Analysis->new(-dbID => $anal_id,
#                                                   -runnable => 'Bio::Pipeline::Runnable::DataMonger',
#                                                   -logic_name => 'DataMonger',
#                                                   -program => 'DataMonger'); 
#    $self->db->get_AnalysisAdaptor->store($dm_analysis);
    my @filters = $dm->filters;
    foreach my $filter($dm->filters) {
       $self->_store_filter($filter, $anal_id);
    }
    foreach my $input_create($dm->input_creates) {
       $self->_store_input_create($input_create, $anal_id);
    }


}

sub _store_input_create {
    my ($self, $input_create, $data_monger_id) = @_;
       
              my $sth = $self->prepare("INSERT INTO input_create 
                                        SET data_monger_id = ?, 
                                            module = ?,
                                            rank = ?");
              $sth->execute($data_monger_id, $input_create->module,$input_create->rank);
              my $dbid = $sth->{mysql_insertid};
              $input_create->dbID($dbid);


              foreach my $argument (@{$input_create->arguments}) {
	              my $sth = $self->prepare("INSERT INTO input_create_argument
        	                                SET input_create_id = ?,
                	                            tag = ?,
                        	                    value = ?");
           	      $sth->execute($input_create->dbID,$argument->tag, $argument->value);
                      my $dbid = $sth->{mysql_insertid};
                      $argument->dbID($dbid);
              }
}

sub _store_filter {
    my ($self, $filter, $data_monger_id) = @_;

              my $sth = $self->prepare("INSERT INTO filter 
                                        SET data_monger_id = ?,
                                            module = ?,
                                            rank = ?");
              $sth->execute($data_monger_id, $filter->module,$filter->rank);
              my $dbid = $sth->{mysql_insertid};
              $filter->dbID($dbid);


              foreach my $argument (@{$filter->arguments}) {
                      my $sth = $self->prepare("INSERT INTO filter_argument
                                                SET filter_id = ?,
                                                    tag = ?,
                                                    value = ?");
                      $sth->execute($filter->dbID,$argument->tag, $argument->value);
                      my $dbid = $sth->{mysql_insertid};
                      $argument->dbID($dbid);
              }
}


1;
