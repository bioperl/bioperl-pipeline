#
# BioPerl module for Bio::Pipeline::IOHandler
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME
Bio::Pipeline::IOHandler input/output object for pipeline


=head1 SYNOPSIS

=head1 DESCRIPTION

The input/output handler for reading input and writing output.

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

package Bio::Pipeline::IOHandler;
use vars qw(@ISA);
use strict;

use Bio::Root::Root;
@ISA = qw(Bio::Root::Root);

=head1 Constructors

=head2 new

  Title   : new
  Usage   : my $io = Bio::Pipeline::IOHandler->new(-dbadaptor=>$dbadaptor,
                                            -dataadaptor=>$datahandler,
                                            -dataadaptormethod=>$datahandler_method);
 
  Function: generates a new Bio::Pipeline::IOHandler
  Returns : a new IOHandler object 
  Args    : dbadaptor to database #note dbadaptor and biodbadaptor are mutally exclusive
            biodbadaptor external biodb adaptor
            biodbname name of biodb
            dataadaptor the adaptor for the object (example Bio::EnsEMBL::DBSQL::ProteinAdaptor)
            dataadaptormethod the method to fetch the object (example fetch_by_dbID)
=cut

sub new {
  my($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($dbID,$dbadaptor_dbname,$dbadaptor_driver,$dbadaptor_host,
      $dbadaptor_user,$dbadaptor_pass,$dbadaptor_module,
      $datahandlers) = $self->_rearrange([ qw( DBID
                                                DBADAPTOR_DBNAME
                                                DBADAPTOR_DRIVER
                                                DBADAPTOR_HOST
                                                DBADAPTOR_USER
                                                DBADAPTOR_PASS
                                                DBADAPTOR_MODULE
                                                DATAHANDLERS)],@args);

  $dbadaptor_dbname || $self->throw("Need a dbadaptor name");
  $dbadaptor_driver || "mysql";
  $dbadaptor_user   || "root";
  $dbadaptor_host   || "localhost";
  $dbadaptor_pass   || "";
  $dbadaptor_module || $self->throw("Need a module for db adaptor");
  $datahandlers     || $self->throw("Need datahandlers in IOHandler constructor");

  $self->dbID($dbID);
  $self->dbadaptor_dbname($dbadaptor_dbname);
  $self->dbadaptor_driver($dbadaptor_driver);
  $self->dbadaptor_host($dbadaptor_host);
  $self->dbadaptor_user($dbadaptor_user);
  $self->dbadaptor_pass($dbadaptor_pass);
  $self->dbadaptor_module($dbadaptor_module);

  @{$self->{'_datahandlers'}} = @{$datahandlers}; 
  
  return $self;
}    

=head1 Fetch/Write methods 
These methods calls adaptors to fetch and write inputs and outputs to database
=cut

=head2 fetch_input 

  Title    : fetch_input
  Function : fetches the input(s) from the adaptors supplied 
  Example  : $contig = $io ->fetch_input("Scaffold_1");
  Returns  : a array ref to the inputs 
  Args     : a string/array ref of strings which specifies the id of the input 

=cut

sub fetch_input {
    my ($self,$input_name) = @_;
    $input_name || $self->throw("Need a name to fetch the input");

    my @datahandlers= sort {$a->rank <=> $b->rank}$self->datahandlers;

    # the datahandlers work this way:
    # each datahandler has an argument. 
    # If this variable is eq 'INPUT', the argument for the datahandlers
    # will be the input name found in the Input table.
    # If this variable is some other string, the argument will be this string
    # If the variable argument is empty, it means that this datahandler call requires
    # no argument.
    #
    # eg. to fetch a sequence from biosql,
    # the datahandlers required will look like that:
    # $datahandler_1( -method=> 'get_BioDatabaseAdaptor'
    #                  -argument=> ''
    #                  -rank => 1 )
    # $datahandler_2 ( -method=> 'fetch_BioSeqDatabase_by_name'
    #                   -argument=> 'swissprot'
    #                   -rank => 2 )
    # 
    # $datahandler_3 ( -method=> 'get_Seq_by_acc'
    #                   -argument=> 'INPUT'
    #                   -rank => 3 )
    #   where the arguement will be the input_name attached to the input object.
    # 
    # if say, what is desired are the genes annotated on this sequence,
    # then an additional datahandler is required,
    #
    # $datahandler_4 ( -method=> 'get_all_genes'
    #                   -argument=> ''
    #                   -rank => 4)
    #                   
    #   
  
  
    my $obj = $self->_fetch_dbadaptor();

    foreach my $datahandler (@datahandlers) {
        my @arguments = sort {$a->rank <=> $b->rank} @{$datahandler->argument};
        my @args;
        for (my $i = 0; $i <=$#arguments; $i++){
            if ($arguments[$i]->name eq 'INPUT') {
                push @args, $input_name;
            }
            else {
              push @args, $arguments[$i]->name;
            }
        }
        my $tmp1 = $datahandler->method;
        $obj = $obj->$tmp1(@args);
    }

  return $obj;
}

=head2 write_output

  Title    : write_output 
  Function : writes the output to database using the adaptors supplied 
  Example  : $io ->write_output($gene);
  Returns  : 
  Args     : an object/array ref to objects to be stored 

=cut

sub write_output {
    my ($self, $object) = @_;
    $object || $self->throw("Need an object to write to database");


    # the datahandlers for an output handler works in the same principle as the
    # input datahandlers. please see above
    
    my @datahandlers= sort {$a->rank <=> $b->rank}$self->datahandlers;
    my $obj = $self->_fetch_dbadaptor();


    # safety check ? Maybe this check should be made before the runnable is even ran
#    $self->warn ("Last output datahandler does not seem to be a STORE function. Strange.")
 #       unless ($datahandlers[$#datahandlers]->argument eq 'OUTPUT');

    my @output_ids;
    my $output_flag = 0;
    foreach my $datahandler (@datahandlers) {
        my @arguments = sort {$a->rank <=> $b->rank} @{$datahandler->argument};
        my @args;
        my $tmp1 = $datahandler->method;
        for (my $i = 0; $i <=$#arguments; $i++){
            if ($arguments[$i]->name eq 'OUTPUT'){
                if (ref($object) eq "ARRAY"){
                  push @args, @{$object};
                }
                else {
                    push @args, $object;
                }

                $output_flag++;
            }
            else {
                push @args, $arguments[$i]->name;
            }
        }
        if($output_flag) {
            @output_ids = $obj->$tmp1(@args);
        }
        else{
          $obj = $obj->$tmp1(@args);
        }
    }

  return @output_ids;
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

=head2 datahandlers 

  Title    : datahandler 
  Function : returns the datahandlers associated with this IOHandler onbject
  Example  : $io->datahandlers(); 
  Returns  : the datahandlers 
  Args     : 

=cut

sub datahandlers {
    my ($self) = @_;
    return @{$self->{'_datahandlers'}};
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

=head2 dbID

  Title   : dbID
  Usage   : $self->dbID($id)
  Function: get set the dbID for this object, only used by Adaptor
  Returns : int
  Args    : int

=cut


sub dbID {
    my ($self,$arg) = @_;

    if (defined($arg)) {
        $self->{'_dbID'} = $arg;
    }
    return $self->{'_dbID'};

}

=head2 adaptor

  Title   : adaptor
  Usage   : $self->adaptor
  Function: get database adaptor, set only for constructor and adaptor usage.
  Returns :
  Args    :

=cut


sub adaptor {
    my ($self,$arg) = @_;

    if (defined($arg)) {
    $self->{'_adaptor'} = $arg;
    }
    return $self->{'_adaptor'};

}

1;



    
          
