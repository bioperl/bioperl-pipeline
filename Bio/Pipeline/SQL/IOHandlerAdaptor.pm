#
# BioPerl module for Bio::Pipeline::IOHandlerAdaptor
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
=head1 NAME
Bio::Pipeline::IOHandlerAdaptor input/output adaptors object for pipeline

=head1 SYNOPSIS
my $in_adpt = Bio::Pipeline::IOHandlerAdaptor->new($db);


=head1 DESCRIPTION

The adaptor to get the input database adaptor 

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

=head1 AUTHOR - 

Email fugui@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut


package Bio::Pipeline::SQL::IOHandlerAdaptor;

use vars qw(@ISA);
use strict;

use Bio::Pipeline::SQL::BaseAdaptor;
use Bio::Pipeline::IOHandler;
use Bio::Pipeline::DataHandler;
use Bio::Pipeline::Argument;

@ISA = qw(Bio::Pipeline::SQL::BaseAdaptor);


=head1 Fetch methods 
These methods retrievs the adaptors
=cut

=head2 fetch_by_dbID

  Title    : fetch_by_dbID
  Function : fetches the adaptor to the input adaptor 
  Example  : $in_adpt = $io ->fetch_by_dbID(1)
  Returns  : Bio::Pipeline::IO 
  Args     : a string which specifies the id of the adaptor 

=cut

sub fetch_by_dbID {
    my ($self,$dbID) = @_;

    $dbID || $self->throw("Need a db ID");

    ##########################################
    #Fetch the datahandlers and the arguments
    ##########################################
    my $query = "SELECT datahandler_id, method, rank from datahandler
                 WHERE iohandler_id = $dbID";
    
    my $sth = $self->prepare($query);
    $sth->execute();

    my @datahandlers;
    my $arg_sth= $self->prepare("SELECT argument_id, tag,value,rank,type FROM argument WHERE datahandler_id=?");
    
    while (my ($datahandler_id, $method,  $rank) = $sth->fetchrow_array){
        $arg_sth->execute($datahandler_id);
        my @args;
        while(my ($argument_id,$tag,$value,$rank,$type) = $arg_sth->fetchrow_array){
          if($argument_id && $value && $rank && $type){
            my $arg = new Bio::Pipeline::Argument(-dbID => $argument_id,
                                                  -rank => $rank,
                                                  -value=> $value,
                                                  -tag  =>$tag,
                                                  -type => $type);
            push @args, $arg;
          }
        }

        
        my $datahandler = new Bio::Pipeline::DataHandler(-dbID       => $datahandler_id,
                                                         -method     => $method,
                                                         -argument   => \@args,
                                                         -rank       => $rank
                                                         );
        push (@datahandlers,$datahandler);
    }

    ###############################################
    #Fetch the dbadaptor and create iohandler
    ###############################################

    $sth = $self->prepare("SELECT io.adaptor_id,io.adaptor_type
                           FROM iohandler io
                           WHERE io.iohandler_id='$dbID'");
    $sth->execute();
    my ($adp_id,$adp_type) = $sth->fetchrow_array();
    my $iohandler;
    if($adp_type eq "DB"){
      my $sql = "SELECT 
                dba.dbname,
                dba.driver,
                dba.host,
                dba.user,
                dba.pass,
                dba.module,
                dba.port
                FROM dbadaptor dba
                WHERE dba.dbadaptor_id = '$adp_id'";
      $sth = $self->prepare($sql);
      $sth->execute;
      my ($dbname,$driver,$host,$user,$pass,$module,$port)  = $sth->fetchrow_array;
      ($dbname && $module) || $self->throw("No DBadaptor found. Can't create an IO object without a dbadaptor");
      $iohandler = Bio::Pipeline::IOHandler->new_ioh_db(  -dbadaptor_dbname   =>$dbname,
                                                          -dbadaptor_driver   =>$driver,
                                                          -dbadaptor_host     =>$host,
                                                          -dbadaptor_user     =>$user,
                                                          -dbadaptor_pass     =>$pass,
                                                          -dbadaptor_module   =>$module,
                                                          -dbadaptor_port     =>$port,
                                                          -dbID               =>$dbID,
                                                          -datahandlers       =>\@datahandlers);
    }
    elsif($adp_type eq "STREAM") {
      my $sql = "SELECT 
                f.module
                FROM streamadaptor f
                WHERE f.streamadaptor_id='$adp_id'";
      $sth = $self->prepare($sql);
      $sth->execute;
      my ($module) = $sth->fetchrow_array;
      $iohandler = Bio::Pipeline::IOHandler->new_ioh_stream(-module=>$module,
                                                            -datahandlers=>\@datahandlers);
    }
    else {
        $self->throw("Unallowed iohandler type $adp_type");
    }


    $iohandler->adaptor($self);
                                    
    return $iohandler;
}


sub _get_dbadaptor {
  my ($self, $module, $dbname) = @_;
      my $sql = "SELECT
                dbadaptor_id
                FROM dbadaptor
                WHERE module = '$module' and
                      dbname = 'dbname' ";
      my $sth = $self->prepare($sql);
      $sth->execute;
      # note -- no checking done here if there are more than one records
      my ($dbadaptor_id)  = ($sth->fetchrow_array)[0];
  return $dbadaptor_id;
}

sub _get_streamadaptor {
  my ($self, $module) = @_;
  my $sql = "SELECT
             streamadaptor_id 
             FROM streamadaptor 
             WHERE module='$module'";
  my $sth = $self->prepare($sql);
  $sth->execute;
  # note -- no checking done here if there are more than one records
  my ($streamadaptor_id) = ($sth->fetchrow_array)[0];
  return $streamadaptor_id;
}


sub store {
  my ($self, $iohandler) = @_;

  my $adap_id;
  my $sth;

  if ($iohandler->type eq "DB") {

    # check if the dbadaptor already exists 
    $adap_id = $self->_get_dbadaptor($iohandler->dbadaptor_module, $iohandler->dbadaptor_dbname);

     if (!defined ($adap_id)) {
       $sth = $self->prepare( qq{
         INSERT INTO dbadaptor
         SET dbname = ? ,
             driver = ?,
             host = ?,
             user = ?,
             pass = ?,
             module = ? } );
      $sth->execute(
         $iohandler->dbadaptor_dbname,
         $iohandler->dbadaptor_driver,
         $iohandler->dbadaptor_host,
         $iohandler->dbadaptor_user,
         $iohandler->dbadaptor_pass,
         $iohandler->dbadaptor_module );

      $sth = $self->prepare( q{
        SELECT last_insert_id()
      } );
      $sth->execute;
      $adap_id = ($sth->fetchrow_array)[0];
    }
  }
  elsif ($iohandler->type eq "STREAM") {
 
    # check if the streamadaptor already exists 
    $adap_id = $self->_get_streamadaptor($iohandler->stream_module);

     if (!defined ($adap_id)) {
       $sth = $self->prepare( qq{
         INSERT INTO streamadaptor
         SET module = ? } );
      $sth->execute($iohandler->stream_module);

      $sth = $self->prepare( q{
        SELECT last_insert_id()
      } );
      $sth->execute;
      $adap_id = ($sth->fetchrow_array)[0];
    }
  }

  if (!defined ($iohandler->dbID)) {
    $sth = $self->prepare( qq{
      INSERT INTO iohandler
         SET adaptor_id = ?,
             adaptor_type = ? } );
    $sth->execute($adap_id, $iohandler->type);

   $sth = $self->prepare( q{
      SELECT last_insert_id()
     } );
   $sth->execute;

   my $dbID = ($sth->fetchrow_array)[0];
   $iohandler->dbID( $dbID );
  }
  else {
    $sth = $self->prepare( qq{
      INSERT INTO iohandler
         SET iohandler_id = ?,
             adaptor_id = ?,
             adaptor_type = ? } );
    $sth->execute($iohandler->dbID, $adap_id, $iohandler->type);
  }

  #now fill up the data handler and argument tables
  
  foreach my $datahandler($iohandler->datahandlers) {
       $sth = $self->prepare( qq{
         INSERT INTO datahandler 
         SET iohandler_id = ?,
             method = ?,
             rank = ? } );
      $sth->execute($iohandler->dbID,$datahandler->method,$datahandler->rank);

      $sth = $self->prepare( q{
        SELECT last_insert_id()
      } );
      $sth->execute;
      my $datahandler_id = ($sth->fetchrow_array)[0];
      $datahandler->dbID($datahandler_id);
     
      foreach my $argument (@{$datahandler->argument}) {
         $sth = $self->prepare( qq{
           INSERT INTO argument 
           SET datahandler_id = ?,
               tag = ?,
               value = ?,
               type = ?,
               rank = ? } );
        $sth->execute($datahandler->dbID,$argument->tag,$argument->value,$argument->type,$argument->rank);

        $sth = $self->prepare( q{
          SELECT last_insert_id()
        } );
        $sth->execute;
        my $argument_id = ($sth->fetchrow_array)[0];
        $argument->dbID($argument_id);
      }
  }


    

}


sub fetch_inputhandler_dbID_by_analysis{
    my ($self,$analysis_id) = @_;

    my $query = "   SELECT iohandler.iohandler_id
                    FROM   analysis_iohandler,iohandler
                    WHERE  analysis_id = ? 
                           and iohandler.type = 'INPUT'
                           and iohandler.iohandler_id= analysis_iohandler.iohandler_id";
    my $sth = $self->prepare($query);
    $sth->execute($analysis_id);

    my @dbIDs;

    while (my ($id) = $sth->fetchrow_array){
        push (@dbIDs,$id);
    }

    return @dbIDs;
}

1;


