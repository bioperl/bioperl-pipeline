package Bio::Pipeline::AbstractXMLImporter;
use strict;
use XML::SimpleObject;
use Bio::Pipeline::Utils::SaxHandler;
use Bio::Pipeline::SQL::DBAdaptor;
use ExtUtils::MakeMaker;
use Bio::Root::Root;
use Bio::Pipeline::PipeConf qw(VERBOSE);
our @ISA=qw(Bio::Root::Root);


sub new{
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    $self->_autoload_methods([qw(dbhost dbname dbuser dbpass schema xml dba)]);
    my ($dbhost, $dbname, $dbuser, $dbpass, $schema, $xml) = 
        $self->_rearrange([qw(DBHOST DBNAME DBUSER DBPASS SCHEMA XML)], @args);
    $self->dbhost($dbhost);
    $self->dbname($dbname);
    $self->dbuser($dbuser);
    $self->dbpass($dbpass);
    $self->schema($schema);
    $self->xml($xml);
    $self->verbose($VERBOSE);
    $self;
}

sub _prepare_dba {
    my ($self, $FORCE) = @_;
    my $DBHOST = $self->dbhost;
    my $DBNAME = $self->dbname;
    my $DBUSER = $self->dbuser;
    my $DBPASS = $self->dbpass;
    my $SCHEMA = $self->schema;
    my $XML    = $self->xml;
    my $dba;
    eval {
        $dba = Bio::Pipeline::SQL::DBAdaptor->new(
            -host   => $DBHOST,
            -dbname => $DBNAME,
            -user   => $DBUSER,
            -pass   => $DBPASS,
        );
    };
    $self->dba($dba);
    my $db_exist=(ref $dba)?1:0; #able to connect
    my $str;
    $str .= defined $DBHOST ? "-h $DBHOST " : "";
    $str .= defined $DBPASS ? "-p$DBPASS " : "";
    $str .= defined $DBUSER ? "-u $DBUSER " : "-u root ";

    if($db_exist){
        my $create;
        if(!$FORCE){
            $create= prompt("A database called $DBNAME already exists.\nContinuing would involve dropping this database and loading a fresh one using $XML.\nWould you like to continue? y/n","n");
        }else{
            $create="y";
        }
        if($create =~/^[yY]/){
            system("mysqladmin $str -f drop $DBNAME > /dev/null ");
        }else{
            $self->debug("Please select another database before running this script. Good bye.\n");
            return 0;
        }
    }

    if(!-e $SCHEMA){
        warn("$SCHEMA doesn't seem to exist. Please use the -schema option to specify where the biopipeline schema is");
        return 0;
    }else{
        $self->debug("Creating $DBNAME\n");
        system("mysqladmin $str -f create $DBNAME");
        $self->debug("Loading Schema...\n");
        system("mysql $str $DBNAME < $SCHEMA");
        $dba = Bio::Pipeline::SQL::DBAdaptor->new(
            -host   => $DBHOST,
            -dbname => $DBNAME,
            -user   => $DBUSER,
            -pass   => $DBPASS);
        $self->dba($dba);
    }
    $dba;
}

sub _prepare_xso {
    my $self=shift;
    my $XML    = $self->xml;
    -e $XML or $self->throw("Cannot find: $XML\n");
    print "Reading Data_setup xml   : $XML\n";
    my $xso1;
    eval {require('XML/Parser.pm');};
    if ($@) {
        eval {require('XML/SAX/PurePerl.pm');};
        if ($@) {
            $self->throw(" you require either XML::SAX::PurePerl.pm or XML::Parser to be installed, none of them seem to be there");
        }else{
            my $handler = Bio::Pipeline::Utils::SaxHandler->new();
            my $parser = XML::SAX::PurePerl->new(Handler => $handler);
            $xso1 = XML::SimpleObject->new( $parser->parse_uri($XML) );
        }
    }else{
        my $parser = XML::Parser->new(ErrorContext => 2, Style => "Tree");
        $xso1 = XML::SimpleObject->new( $parser->parsefile($XML) );
    }
    return $xso1;
}

=head2 _autoload_methods  

This subroutine is usually invoked at the very beginning line of
constructor, to set subroutine names for getter and setters.  
                                                              
SYNOPSIS                                                      
                                                              
  sub new{                                                    
    my ($class, @args) = @_;                                  
    my $self = $class->SUPER::new(@args);                     
                                                              
    $self->_autoload_methods([qw(dbhost dbname dbuser dbpass)]); # Don't add if unnecessary.
                                                              
    # Then, say                                               
                                                              
    my ($dbhost) = $self->_rearrange([qw(DBHOST)], @args);    
    $self->dbhost($dbhost);                                   
                                                              
    return $self;
  }                                                           
                                                              
=cut 


sub _autoload_methods {
    my ($self, $arg) = @_;
    if(defined $arg && ref($arg) eq 'ARRAY'){
        push @{$self->{_autoload_methods}}, @{$arg};
# equally explicitly declare the subs !!!
        use subs @{$self->{_autoload_methods}};
    }
    return $self->{_autoload_methods};
}

sub AUTOLOAD{
    return if our $AUTOLOAD =~ /::DESTROY$/;
    my ($self, $arg) = @_;
    my $field = $AUTOLOAD;
    $field =~ /::([\w\d]+)$/;
    if($self->_autoload_methods && grep /$1/, @{$self->_autoload_methods}){
        $self->{$field} = $arg if defined $arg;
        return $self->{$field};
    }else{
        $self->throw("Can't find the method '$field'");
    }
}


