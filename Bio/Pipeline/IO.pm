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

package Bio::Pipeline::IO;
use vars qw(@ISA);
use strict;

use Bio::Root::Root;
@ISA = qw(Bio::Root::Root);

=head1 Constructors

=head2 new

  Title   : new
  Usage   : my $io = Bio::Pipeline::IO->new(-dbadaptor=>$dbadaptor,
                                            -biodbadaptor=>$biodbadaptor,
                                            -biodbname=>$biodbname,
                                            -dataadaptor=>$data_adaptor,
                                            -dataadaptormethod=>$data_adaptor_method);
 
  Function: generates a new Bio::Pipeline::IO
  Returns : a new IO object 
  Args    : dbadaptor to database #note dbadaptor and biodbadaptor are mutally exclusive
            biodbadaptor external biodb adaptor
            biodbname name of biodb
            dataadaptor the adaptor for the object (example Bio::EnsEMBL::DBSQL::ProteinAdaptor)
            dataadaptormethod the method to fetch the object (example fetch_by_dbID)
=cut

sub new {
  my($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($dbadaptor,$data_adpt,$data_adpt_method) = $self->_rearrange([qw(DBADAPTOR
                                                                     DATAADAPTOR
                                                                     DATAADAPTORMETHOD)],@args);
  $dbadaptor || $self->throw("Need a dbadaptor");
  $data_adpt || $self->throw("Need a data adaptor");
  $data_adpt_method || $self->throw("Need a data adaptor method");

  $self->dbadaptor($dbadaptor);
  $self->data_adaptor($data_adpt);
  $self->data_adaptor_method($data_adpt_method);
  
  return $self;
}    

=head 1 Fetch/Write methods 
These methods calls adaptors to fetch and write inputs and outputs to database

=head2 fetch_input 

  Title    : fetch_input
  Function : fetches the input from the adaptors supplied 
  Example  : $contig = $io ->fetch_input("Scaffold_1");
  Returns  : the input that is specified in input_dba table 
  Args     : a string which specifies the id of the input 

=cut

sub fetch_input {
  my ($self,$name) = @_;
  $name || $self->throw("Need a name to fetch the input");
  my $input = $self->_doit($name);
  return $input;
}

=head2 write_output

  Title    : write_output 
  Function : writes the output to database using the adaptors supplied 
  Example  : $io ->write_output($gene);
  Returns  : 
  Args     : the object specified in the output_dba table 

=cut

sub write_output {
  my ($self, $object) = @_;
  $object || $self->throw("Need an object to write to database");
  $self->_doit($object);
}

=head2 _doit 

  Title    : _doit 
  Function : internal function that actually does the work, called by write_output and fetch_input 
  Example  : $self->_doit($name) 
  Returns  : a input object if called by fetch_input 
  Args     : name (string) or a object 

=cut

sub _doit {
    my ($self,$object) = @_;
    my $adaptor;
    if($self->dbadaptor){
        $adaptor = $self->dbadaptor;
    }
    else {
      $self->throw("Need a db adaptor");
    }
    my $data_adaptor = $self->data_adaptor;
    my $data_method = $self->data_adaptor_method;
    
    my $input = $adaptor->$data_adaptor->${data_method}($object);
    if ($input){
      return $input;
    }
    return;
}
=head1 Member variable access

These methods let you get at and set the member variables

=head2 dbadaptor 

  Title    : dbadaptor 
  Function : returns/sets the dbadaptor object 
  Example  : $io->dbadaptor($db); 
  Returns  : the dbadaptor 
  Args     : optionally, the new dbadaptor 

=cut
 
sub dbadaptor {
    my ($self,$adaptor) = @_;
    if (defined $adaptor) {
        $self->{'_dbadaptor'} = $adaptor;
    }
    return $self->{'_dbadaptor'};
}

=head2 data_adaptor 

  Title    : data_adaptor 
  Function : returns/sets the get data_adaptor string 
  Example  : $io->data_adaptor($string); 
  Returns  : the data_adaptor string eg (get_ProteinAdaptor) 
  Args     : optionally, the new data_adaptor string 

=cut

sub data_adaptor {
    my ($self,$adaptor) = @_;
    if (defined $adaptor) {
        $self->{'_data_adaptor'} = $adaptor;
    }
    return $self->{'_data_adaptor'};
}

=head2 data_adaptor_method 

  Title    : data_adaptor_method 
  Function : returns/sets the get data_adaptor_method string 
  Example  : $io->data_adaptor_method($string); 
  Returns  : the data_adaptor_method string eg (fetch_by_dbID) 
  Args     : optionally, the new data_adaptor_method string 

=cut
sub data_adaptor_method {
    my ($self,$method) = @_;
    if (defined $method) {
        $self->{'_data_adaptor_method'} = $method;
    }
    return $self->{'_data_adaptor_method'};
}

1;



    
          
