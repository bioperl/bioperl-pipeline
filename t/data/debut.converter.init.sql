# THIS data are same in debut.converter.xml
INSERT INTO converters VALUES (1, 'Bio::SeqFeatureIO');

#INSERT INTO converters VALUES (2, 'Bio::BioToEns::Beacon');

INSERT INTO converter_methods VALUES (1, 1, 'new', 1);
INSERT INTO converter_methods VALUES (2, 1, 'convert', 2);

INSERT INTO converter_arguments VALUES (1, 1, '-in', 'Bio::SeqFeature::Gene::GeneStructure', 1);
INSERT INTO converter_arguments VALUES (2, 1, '-out', 'Bio::EnsEMBL::Gene', 2);
INSERT INTO converter_arguments VALUES (3, 2, '-input', 'INPUT', 1);


INSERT INTO converters SET converter_id=4, module='jalfjalsfkajlsf';

