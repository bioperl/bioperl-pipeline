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
Bio::Pipeline::InputDBAAdaptor input/output object for pipeline

=head1 SYNOPSIS
my $in_adpt = Bio::Pipeline::InputDBAAdaptor->new($db);


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

=head1 AUTHOR - Shawn Hoon

Email shawnh@fugu-sg.org 
=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut

package Bio::Pipeline::SQL::OutputDBAAdaptor;

use vars qw(@ISA);
use strict;

use Bio::Pipeline::SQL::BaseAdaptor;
use Bio::Pipeline::IO;
@ISA = qw(Bio::Pipeline::SQL::BaseAdaptor);

=head 1 Fetch methods 
These methods retrievs the adaptors

=head2 fetch_by_dbID

  Title    : fetch_by_dbID
  Function : fetches the adaptor to the output adaptor 
  Example  : $out_adpt = $io->fetch_by_dbID(1)
  Returns  : Bio::Pipeline::IO 
  Args     : a string which specifies the id of the adaptor 
=cut

sub fetch_by_dbID {
    my ($self,$id) = @_;
    $id || $self->throw("Need a db ID");
 $id || $self->throw("Need a db ID");

    my $sth = $self->prepare("SELECT 
                              dba.dbname,
                              dba.driver,
                              dba.host,
                              dba.user,
                              dba.pass,
                              dba.module,
                              oup.biodbadaptor_method,
                              oup.biodbname,
                              oup.data_adaptor,
                              oup.data_adaptor_method
                              FROM output_dba oup, dbadaptor dba
                              WHERE oup.output_dba_id = '$id' AND
                              oup.dbadaptor_id = dba.dbadaptor_id"
                              );
    $sth->execute();

     my ($dbname,$driver,$host,$user,$pass,$module,$biodbadaptor,$biodbname,$data_adaptor,$data_adaptor_method)  = $sth->fetchrow_array;
     ($dbname && $module) || $self->throw("No DBadaptor found.");
     ($data_adaptor && $data_adaptor_method) || $self->throw("No data adaptor or data adaptor method found.");

    #if biodbadaptor exist, need another layer to get the dbadaptor
    my $ioadpt = Bio::Pipeline::IO->new(-dbadaptor_dbname =>$dbname,
                                        -dbadaptor_driver =>$driver,
                                        -dbadaptor_host   =>$host,
                                        -dbadaptor_user   =>$user,
                                        -dbadaptor_pass   =>$pass,
                                        -dbadaptor_module =>$module,
                                        -biodbadaptor     =>$biodbadaptor,
                                        -biodbname        =>$biodbname,
                                        -data_adaptor     =>$data_adaptor,
                                        -data_adaptor_method  =>$data_adaptor_method);

    return $ioadpt;
    
}
#assume 1 analysis, 1 output dbadaptor
sub fetch_by_analysisID {
    my ($self,$id) = @_;
    $id || $self->throw("Need a db ID");
    my $sth  = $self->prepare("SELECT
                               output_dba_id 
                               FROM output_dba
                               WHERE analysis_id='$id'"
                             );
    $sth->execute();
    my ($job_id) = $sth->fetchrow_array;
    if ($job_id){
        return $self->fetch_by_dbID($job_id);
    }
    else {
        $self->throw("No outputdba with analysis id $id");
    }
}
     
                           
    
sub _fetch_db_adaptor {
    my ($self,$id) = @_;
    my $sth = $self->prepare("SELECT dbname,driver,host,user,pass,module 
                              FROM dbadaptor
                              WHERE dbadaptor_id = $id");
    $sth->execute();
    my ($dbname,$driver,$host,$user,$pass,$module) = $sth->fetchrow_array();
    if($module =~/::/)  {
         $module =~ s/::/\//g;
         require "${module}.pm";
         $module =~s/\//::/g;
     }
    my $db_adaptor = "${module}"->new(-dbname=>$dbname,-user=>$user,-host=>$host,-driver=>$driver,-pass=>$pass);

    return $db_adaptor;
}


1;

