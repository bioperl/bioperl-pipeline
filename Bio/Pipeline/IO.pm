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
  my ($dbadaptor_dbname,$dbadaptor_driver,$dbadaptor_host,
      $dbadaptor_user,$dbadaptor_pass,$dbadaptor_module,
      $biodbadaptor,$biodbname,$data_adaptor,
      $data_adaptor_method) = $self->_rearrange([qw(DBADAPTOR_DBNAME
                                                    DBADAPTOR_DRIVER
                                                    DBADAPTOR_HOST
                                                    DBADAPTOR_USER
                                                    DBADAPTOR_PASS
                                                    DBADAPTOR_MODULE
                                                    BIODBADAPTOR
                                                    BIODBNAME
                                                    DATA_ADAPTOR
                                                    DATA_ADAPTOR_METHOD)],@args);

  $dbadaptor_dbname || $self->throw("Need a dbadaptor name");
  $dbadaptor_driver || "mysql";
  $dbadaptor_host   || "localhost";
  $dbadaptor_pass   || "";
  $dbadaptor_module || $self->throw("Need a module for db adaptor");
  $data_adaptor || $self->throw("Need a data adaptor");
  $data_adaptor_method || $self->throw("Need a data adaptor method");

  $self->dbadaptor_dbname($dbadaptor_dbname);
  $self->dbadaptor_driver($dbadaptor_driver);
  $self->dbadaptor_host($dbadaptor_host);
  $self->dbadaptor_user($dbadaptor_user);
  $self->dbadaptor_pass($dbadaptor_pass);
  $self->dbadaptor_module($dbadaptor_module);
  $biodbadaptor && $self->biodbadpator($biodbadaptor);
  $biodbname && $self->biodbname($biodbname);
  $self->data_adaptor($data_adaptor);
  $self->data_adaptor_method($data_adaptor_method);
  
  return $self;
}    

=head 1 Fetch/Write methods 
These methods calls adaptors to fetch and write inputs and outputs to database

=head2 fetch_input 

  Title    : fetch_input
  Function : fetches the input(s) from the adaptors supplied 
  Example  : $contig = $io ->fetch_input("Scaffold_1");
  Returns  : a array ref to the inputs 
  Args     : a string/array ref of strings which specifies the id of the input 

=cut

sub fetch_input {
  my ($self,$name) = @_;
  $name || $self->throw("Need a name to fetch the input");
  my $adaptor = $self->_fetch_dbadaptor();
  $adaptor || $self->throw("Need a db adaptor");

  if ($self->biodbadaptor() && $self->biodbname()){
      my $biodbadaptor = $self->biodbadaptor();
      my $biodbname = $self->biodbname();
      $adaptor = $adaptor->${biodbadaptor}($biodbname);
  }
  my $data_adaptor = $self->data_adaptor;
  my $data_method = $self->data_adaptor_method;
  my @methods = split("->",$data_method);
  my $meth = $adaptor->$data_adaptor;
  
  #loop through each method call
  for (my $i = 0; $i < $#methods; $i++) {
      $meth = $self->_get_method_ref($meth,$methods[$i]);
  }
  my $last = $methods[-1];
  my $input = $meth->${last}($name);

  #my $input =  $adaptor->$data_adaptor->${data_method}($name); 
  
  return $input;
}
sub _get_method_ref {
    my ($self,$object,$methodname) = @_;
    if ($object->can($methodname)){
      return $object->$methodname;
    }
    else {
      $self->throw("Cannot call $methodname using ".(ref($object)||$object));
  }
}
=head2 write_output

  Title    : write_output 
  Function : writes the output to database using the adaptors supplied 
  Example  : $io ->write_output($gene);
  Returns  : 
  Args     : an object/array ref to objects  specified in the output_dba table 

=cut

sub write_output {
  my ($self, $object) = @_;
  $object || $self->throw("Need an object to write to database");
  my $adaptor = $self->_fetch_dbadaptor();
  $adaptor || $self->throw("Need a db adaptor");

  if ($self->biodbadaptor() && $self->biodbname()){
      my $biodbadaptor = $self->biodbadaptor();
      my $biodbname = $self->biodbname();
      $adaptor = $adaptor->${biodbadaptor}($biodbname);
  }
  my $data_adaptor = $self->data_adaptor;
  my $data_method = $self->data_adaptor_method;

  if (ref($object) eq "ARRAY"){
      $adaptor->$data_adaptor->${data_method}(@{$object});
  }
  else {
      $adaptor->$data_adaptor->${data_method}($object);
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
sub dbadaptor_dbname {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_dbname'} = $value;
  }
  return $self->{'_dbadaptor_dbname'};
}

#get/set methods for dbadaptor params
sub dbadaptor_driver {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_driver'} = $value;
  }
  return $self->{'_dbadaptor_driver'};
}

sub dbadaptor_user {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_user'} = $value;
  }
  return $self->{'_dbadaptor_user'};
}

sub dbadaptor_pass {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_pass'} = $value;
  }
  return $self->{'_dbadaptor_pass'};
}
sub dbadaptor_module {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_module'} = $value;
  }
  return $self->{'_dbadaptor_module'};
}
sub dbadaptor_host {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_host'} = $value;
  }
  return $self->{'_dbadaptor_host'};
}

sub biodbadaptor{
  my ($self,$value) = @_;
  if ($value){
    $self->{'_biodbadaptor'} = $value;
  }
  return $self->{'_biodadaptor'};
}
sub biodbname{
  my ($self,$value) = @_;
  if ($value){
    $self->{'_biodbname'} = $value;
  }
  return $self->{'_biodbname'};
}
sub _fetch_dbadaptor {
    my ($self,) = @_;
    my $dbname = $self->dbadaptor_dbname();
    my $driver = $self->dbadaptor_driver();
    my $host   = $self->dbadaptor_host();
    my $user   = $self->dbadaptor_user();
    my $pass   = $self->dbadaptor_pass();
    my $module = $self->dbadaptor_module();

    if($module =~/::/)  {
         $module =~ s/::/\//g;
         require "${module}.pm";
         $module =~s/\//::/g;
    }
    
    my $db_adaptor = "${module}"->new(-dbname=>$dbname,-user=>$user,-host=>$host,-driver=>$driver,-pass=>$pass);

    return $db_adaptor;
}

1;



    
          
