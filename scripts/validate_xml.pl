#!/usr/bin/perl -w
#Biopipe script for validating xml against schema
#
#Cared for by Shawn Hoon <shawnh@stanford.edu>
#
#Copyright Shawn Hoon
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs after the code

use strict;
use vars qw($USAGE);
use XML::SAX::ParserFactory;
use XML::Validator::Schema;
use Getopt::Long;

$USAGE = "validate_xml.pl [-h] [-xsd (../xml/pipeline.xsd)] [-xml]\n";
my ($xsd) = "../xml/pipeline.xsd";
my ($xml,$help) = (undef,undef);

&GetOptions('help|h'  =>\$help,
            'xsd=s'   =>\$xsd,
            'xml=s'   =>\$xml
            );
if($help){
  exec('perldoc', $0);
  die;
}
if(!defined $xml){
  die($USAGE."\n\t Must specify xml file\n");
}

my $validator = XML::Validator::Schema->new(file => $xsd);
my $parser = XML::SAX::ParserFactory->parser(Handler => $validator);
eval { $parser->parse_uri($xml) };
if($@){
  die "File failed validation: $@";
}
else {
  print "\n$xml validated successfully\n";
}


__END__

=head1 NAME

validate_xml.pl - script for validating biopipe xml against the schema

=head1 SYNOPSIS

% validate_xml.pl -xsd ../xml/pipeline.xsd -xml test.xml

=head1 DESCRIPTION

This script will validate an xml file against the biopipe xml schema

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to
the Bioperl mailing list.  Your participation is much appreciated.

  bioperl-l@bioperl.org               - General discussion
  http://bioperl.org/MailList.shtml   - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via email
or the web:

  bioperl-bugs@bioperl.org
  http://bioperl.org/bioperl-bugs/

=head1 AUTHOR - Shawn Hoon 

Email shawnh@stanford.edu 

=cut

