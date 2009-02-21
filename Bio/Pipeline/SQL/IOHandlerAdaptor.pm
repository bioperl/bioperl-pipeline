#
# BioPerl module for Bio::Pipeline::IOHandlerAdaptor
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME

Bio::Pipeline::IOHandlerAdaptor - input/output adaptors object for pipeline

=head1 SYNOPSIS

  my $in_adpt = Bio::Pipeline::IOHandlerAdaptor->new($db);

=head1 DESCRIPTION

The adaptor to get IOHandlers 

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

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
    my $arg_sth1 = $self->prepare("SELECT a.argument_id, a.tag,a.value,a.rank,a.type
                                   FROM argument a 
                                   WHERE a.datahandler_id=?");

    while (my ($datahandler_id, $method,  $rank) = $sth->fetchrow_array){
        $arg_sth1->execute($datahandler_id);
        my @args;
        while(my ($argument_id,$tag,$value,$rank,$type) = $arg_sth1->fetchrow_array){
          if($argument_id && $value && $rank && $type){
            my $arg = new Bio::Pipeline::Argument(-dbID => $argument_id,
                                                  -rank => $rank,
                                                  -value=> $value,
                                                  -tag  => $tag,
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

    $sth = $self->prepare("SELECT io.adaptor_id,io.adaptor_type,io.type
                           FROM iohandler io
                           WHERE io.iohandler_id='$dbID'");
    $sth->execute();
    my ($adp_id,$adp_type,$type) = $sth->fetchrow_array();
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
      $iohandler = Bio::Pipeline::IOHandler->new_ioh_db(  -type               =>$type, 
                                                          -dbadaptor_dbname   =>$dbname,
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
                f.module,f.file_path,f.file_suffix
                FROM streamadaptor f
                WHERE f.streamadaptor_id='$adp_id'";
      $sth = $self->prepare($sql);
      $sth->execute;
      my ($module,$file_path,$file_suffix) = $sth->fetchrow_array;
      $iohandler = Bio::Pipeline::IOHandler->new_ioh_stream(-type=>$type,
                                                            -module=>$module,
                                                            -file_path=>$file_path,
                                                            -file_suffix=>$file_suffix,
                                                            -dbID  => $dbID,
                                                            -datahandlers=>\@datahandlers);
    }
    elsif($adp_type eq "CHAIN") {
      $iohandler = Bio::Pipeline::IOHandler->new_ioh_chain(-type=>$type,-dbID=>$dbID);
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
                      dbname = '$dbname' ";
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

sub store_if_needed {
    my ($self,$iohandler) = @_;
    return $self->store($iohandler) if !$iohandler->dbID;

    my $sth = $self->prepare("SELECT iohandler_id 
                              FROM iohandler 
                              WHERE iohandler_id=?");
    $sth->execute($iohandler->dbID);
    my ($id) = $sth->fetchrow_array;
    return $self->store($iohandler) if !$id;

    return $id;
}


=head2 store 

  Title    : store 
  Function : stores the IOHandler
  Example  : $dbID = $ioadp->store($iohandler)
  Returns  : an int dbID
  Args     : L<Bio::Pipeline::IOHandler> 

=cut

sub store {
  my ($self, $iohandler) = @_;

  my $adap_id;
  my $sth;

  if ($iohandler->adaptor_type eq "DB") {

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
  elsif ($iohandler->adaptor_type eq "STREAM") {
 
    # check if the streamadaptor already exists 
    $adap_id = $self->_get_streamadaptor($iohandler->stream_module);

     if (!defined ($adap_id)) {
       $sth = $self->prepare( qq{
         INSERT INTO streamadaptor
         SET module = ?,file_path=?,file_suffix=? } );
      $sth->execute($iohandler->stream_module,$iohandler->file_path,$iohandler->file_suffix);

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
             adaptor_type = ?,
             type = ?} );
    $sth->execute($adap_id, $iohandler->adaptor_type,$iohandler->type);

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
             adaptor_type = ?,
             type = ?} );
    $sth->execute($iohandler->dbID, $adap_id, $iohandler->adaptor_type,$iohandler->type);
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
    
      if($datahandler->argument){
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
}


=head2 store_map_ioh 

  Title    : store_map_ioh 
  Function : stores the mapping iohandler information 
  Example  : $dbID = $ioadp->store_map_ioh($analysis_id,
                                           $prev_iohandler_id,
                                           $mapped_iohandler_id);
  Returns  : an int dbID
  Args     : analysis_dbID,previous_iohandler_id,mapped_iohandler_id

=cut

sub store_map_ioh {
    my ($self,$anal_id,$prev_ioh_id,$map_ioh_id) = @_;
    my $query = "INSERT INTO iohandler_map
                 SET analysis_id =?,
                     prev_iohandler_id=?,
                     map_iohandler_id=?";
    my $sth = $self->prepare($query);
    $sth->execute ($anal_id,$prev_ioh_id,$map_ioh_id);
    my $id = $sth->{'mysql_insert_id'};
    return $id;
}

=head2 get_mapped_ioh 

  Title    : get_mapped_ioh 
  Function : returns the mapped iohandler object
  Example  : $ioh = $ioadp->get_mapped_ioh($analysis_id,
                                           $prev_iohandler_id,
                                           );
  Returns  : L<Bio::Pipeline::IOHandler> 
  Args     : analysis_dbID,previous_iohandler_id

=cut

sub get_mapped_ioh {
    my ($self,$anal_id,$prev_ioh_id) = @_;
    my ($query,$sth);
  
    if($prev_ioh_id){
      $query = "SELECT map_iohandler_id 
                 FROM iohandler_map 
                 WHERE analysis_id = ? 
                 AND   prev_iohandler_id = ?";
      $sth = $self->prepare($query);
      $sth->execute($anal_id,$prev_ioh_id);
    }
    else {
      $query = "SELECT map_iohandler_id
                FROM iohandler_map 
                WHERE analysis_id= ?";
      $sth = $self->prepare($query);
      $sth->execute($anal_id);
    }
            
    my @map_ioh = $sth->fetchrow_array;
    unless ($#map_ioh <= 0){
      $self->throw("More than one possible ioh to map to, ambiguous.");
    }
    
    #if no map, reuse old one
    my $map_ioh  = $map_ioh[0] || $prev_ioh_id;

    $map_ioh || return;

    my $ioh = $self->fetch_by_dbID($map_ioh);
    $ioh || $self->throw("Unable to retrieve IOHandler of dbID $map_ioh");

    return $ioh;
}

sub fetch_new_input_ioh {
    my ($self,$analysis_id,$job_id) = @_;
    my $sth = $self->prepare("SELECT iohandler_id 
                              FROM   analysis_iohandler ai, iohandler ioh
                              WHERE  ai.analysis_id=? 
                              AND ioh.iohandler_id = ai.iohandler_id
                              AND ioh.type=?");
    $sth->execute($analysis_id,"NEW_INPUT");
    my $ioh_id = $sth->fetchrow_array();
    $ioh_id || $self->throw("Analysis $analysis_id has no new_input iohandler");
    my $ioh = $self->fetch_by_dbID($ioh_id,$job_id);

    $ioh || $self->throw("No IOHandler for new input found");

    return $ioh;
}




1;


