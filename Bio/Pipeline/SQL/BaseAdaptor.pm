
=head1 NAME

Bio::Pipeline::SQL::BaseAdaptor - Base Adaptor for DB::SQL::adaptors

=head1 SYNOPSIS

    # base adaptor provides

    # SQL prepare function
    $adaptor->prepare("sql statement");

    # get of root db object
    $adaptor->db();

    # delete memory cycles
    $adaptor->deleteObj();


=head1 DESCRIPTION

This is a true base class for Adaptors in the Bio::Pipeline::SQL
system. Original idea from Arne Stabenau (stabenau@ebi.ac.uk)

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::Pipeline::SQL::BaseAdaptor;

use vars qw(@ISA);
use strict;
use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);

sub new {
    my ($class,$dbobj) = @_;

    my $self = $class->SUPER::new();

    if( !defined $dbobj || !ref $dbobj ) {
	$self->throw("Don't have a db [$dbobj] for new adaptor");
    }

    $self->db($dbobj);

    return $self;
}

=head2 prepare

 Title   : prepare
 Usage   : $sth = $adaptor->prepare("select yadda from blabla")
 Function: provides a DBI statement handle from the adaptor. A convience
           function so you do not have to write $adaptor->db->prepare all the
           time
 Example :
 Returns : 
 Args    :


=cut

sub prepare{
   my ($self,$string) = @_;

   return $self->db->prepare($string);
}

=head2 prepare_execute

 Title	 : prepare_execute
 Usage	 : $sth = $adaptor->prepare("select yaya from bear where name='?'", 'not me');
 Function: provides a DBI statement and execute it.

=cut

#sub prepare_execute{
#	my ($self, $query, @args) = @_;
#	my $sth = $self->prepare($query);
#	$sth->execute(@args);
#	$self->throw("cannot execute because of $@") if($@);
#	return $sth;
#}
	

=head2 db

 Title   : db
 Usage   : $obj->db($newval)
 Function: 
 Returns : value of db
 Args    : newvalue (optional)


=cut

sub db{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'db'} = $value;
    }
    return $obj->{'db'};

}


=head2 get_last_id

 Title   : get_last_id
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_last_id{
   my ($self) = @_;

   my $sth = $self->prepare("select last_insert_id()");
   my $rv  = $sth->execute;
   my $rowhash = $sth->fetchrow_hashref;
   return $rowhash->{'last_insert_id()'};
}





1;
