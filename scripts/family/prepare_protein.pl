use Getopt::Long;
use Bio::SeqIO;


my $USAGE =<<END;

******************************
*prepare_protein.pl
******************************
This script creates the description and fasta  file necessary for the protein family pipeline to run 

Usage: prepare_protein.pl -swiss  path_to_swissprot_peptides_file 
                            -trembl path_to_trembl_peptide_file
                            -fasta  the blast db of the peptide file dumped in fasta format
                            -desc   the path to the description file name from swissprot and trembl entires
                            -help    displays this help


END

GetOptions(
    'swiss=s'  => \$SWISS,
    'trembl=s' => \$TREMBL,
    'fasta=s'  => \$FASTA,
    'desc=s'   => \$DESC,
    'help'     => \$HELP
)
or die $USAGE;
$HELP && die $USAGE;

$SWISS || die $USAGE;
$TREMBL || die $USAGE;

my $blast_pep_file = $FASTA||"swiss_trembl.fa";
my $desc_file      = $DESC || "family.desc"; 

my $swiss_file = $SWISS;
-e $swiss_file || die("$swiss_file doesn't exist");

print STDERR "Using swissprot file $swiss_file\n";

my $sptrembl_file = $TREMBL;

-e $sptrembl_file || die("$sptrembl_file doesn't exist");

print STDERR "Using sptrembl file $swiss_file\n";

#create description file for swissprot and sptrembl files
#as well as peptide files in fasta format

print STDERR "Creating swissprot description file and fasta file\n";

my ($swiss_desc,$swiss_fasta) = &print_swiss_format_file('swissprot',$swiss_file);

print STDERR "Creating sptrembl description file and fasta file\n";

my ($sptrembl_desc,$sptrembl_fasta) = &print_swiss_format_file('sptrembl',$sptrembl_file);

my $cat_desc = "$swiss_desc $sptrembl_desc";

print STDERR "Creating $desc_file\n";
system("cat $cat_desc > $desc_file"); 
unlink $swiss_desc;
unlink $sptrembl_desc;

#create blast peptide file

my $cat_pep = "$swiss_fasta $sptrembl_fasta";

print STDERR "Creating peptide file for blasting $blast_pep_file\n";
system("cat $cat_pep > $blast_pep_file");
system("formatdb -p T -i $blast_pep_file");

unlink $swiss_fasta;
unlink $sptrembl_fasta;

print STDERR "Setup Completed for peptide files\n";

print "****************************************************************\n";
print STDERR "Swissprot and Trembl Description file : $desc_file\n";
print STDERR "Swissprot and Trembl Fasta file       : $blast_pep_file\n";

print STDERR "You may now proceed to cat the ensembl peptides to $blast_pep_file\n";
print "****************************************************************\n";



sub print_swiss_format_file {
    my ($db,$file) = @_;
    my $sio = Bio::SeqIO->new(-file=>$file,-format=>"swiss");

    my $desc_file = time . ".".int(rand(1000));
    my $fasta_file = time . ".".int(rand(1000));
    my $sout = Bio::SeqIO->new(-file=>">$fasta_file",-format=>"fasta");
    open (DESC, ">$desc_file");

    while (my $seq = $sio->next_seq){
        my $species = $seq->species;
        if($species){
          my $taxon_str = "taxon_id=".$species->ncbi_taxid.";taxon_genus=".$species->genus.
                          ";taxon_species=".$species->species.";taxon_sub_species=".
                          $species->sub_species.";taxon_common_name=".
                          $species->common_name.";taxon_classification=".join(":",$species->classification);

        print DESC $db."\t".$seq->display_id."\t".$seq->desc."\t".$taxon_str."\n";
        $sout->write_seq($seq);
        }
    }
    close DESC;

    return ($desc_file,$fasta_file);
}




