#!/usr/local/bin/ruby -w


require 'lib/evo/sequence/sequence'
require 'lib/evo/msa/msa'
require 'lib/evo/msa/msa_factory'
require 'lib/evo/io/writer/fasta_writer'
require 'lib/evo/io/parser/fasta_parser'


module Evoruby

  if ARGV.length != 1
    puts "usage: select_same_gn.rb <fasta formatted multiple sequence file>"
    exit
  end

  input = ARGV[ 0 ]
  f = MsaFactory.new()

  IGNORE_SEQS_LACKING_GN = false
  IGNORE_FRAGMENTS = false
  IGNORE_SPECIES = true

  msa = nil

  begin
    msa = f.create_msa_from_file( input, FastaParser.new() )
  rescue Exception => e
    puts "error: " + e.to_s
    exit
  end

  outbase = input.sub( /\..+/, "" )

  outfile = File.open(outbase + "_log.txt" , "w")

  all_names = Set.new
  all_seqs_per_species = Hash.new
  all_msa_per_species = Hash.new
  gn_to_seqs = Hash.new
  unique_genes_msa = Msa.new
  longest_non_unique_genes_msa = Msa.new
  gn_re = /GN=(\S+)/
  fragment_re = /fragment/i
  species_re = /\[([A-Z0-9]{3,5})\]$/

  frag_counter = 0
  no_gn_counter = 0
  same_seq_counter = 0

  for i in 0 ... msa.get_number_of_seqs()
    seq = msa.get_sequence( i )
    name = seq.get_name
    if all_names.include?( name )
      puts "error: sequence name \"" + name + "\" is not unique (#" + i.to_s + ")"
      exit
    else
      all_names << name
    end

    if IGNORE_FRAGMENTS && fragment_re.match( name )
      outfile.puts("ignored because fragment: " + name)
      frag_counter += 1
      next
    end

    species = nil
    if IGNORE_SPECIES || species_re.match( name )
      unless IGNORE_SPECIES
        species = species_re.match( name )[ 1 ]
      else
        species = "XXXXX"
      end

      unless all_seqs_per_species.has_key?( species )
        all_seqs_per_species[ species ] = Set.new
      end
      all_seqs = all_seqs_per_species[ species ]
      mol_seq = seq.get_sequence_as_string.upcase
      if all_seqs.include?( mol_seq )
        outfile.puts("ignored because identical sequence in same species: " + name )

        same_seq_counter += 1
        next
      else
        all_seqs << mol_seq
      end
    else
      puts "error: no species for: " + name
      exit
    end

    gn_match = gn_re.match( name )
    if IGNORE_SEQS_LACKING_GN
      unless gn_match
        outfile.puts( "ignored because no GN=: " + name )
        no_gn_counter += 1
        next
      end
    else
      unless gn_match
        outfile.puts( "no GN=: " + name )
      end
    end

    gn =nil
    if gn_match
      gn = gn_match[1] + "_" + species
    else
      if IGNORE_SEQS_LACKING_GN
        puts "cannot be"
        exit
      end
      gn = name
    end

    unless gn_to_seqs.has_key?(gn)
      gn_to_seqs[gn] = Msa.new
    end
    gn_to_seqs[gn].add_sequence(seq)
  end

  if IGNORE_FRAGMENTS
    outfile.puts( "Sequences ignored because \"fragment\" in desc                : " + frag_counter.to_s )
  end
  
  if IGNORE_SEQS_LACKING_GN
    outfile.puts( "Sequences ignored because no \"GN=\" in desc                  : " + no_gn_counter.to_s )
  end
  outfile.puts( "Sequences ignored because identical sequence in same species: " + same_seq_counter.to_s )
  outfile.puts
  outfile.puts

  counter = 1
  gn_to_seqs.each_pair do |gene,seqs|
    seq = nil
    if seqs.get_number_of_seqs > 1
      outfile.puts( counter.to_s + ": " + gene )
      outfile.puts( seqs.to_fasta )
      outfile.puts
      outfile.puts
      counter += 1
      longest = 0
      longest_seq = nil
      for j in 0 ... seqs.get_number_of_seqs()
        current = seqs.get_sequence( j )
        if current.get_length > longest
          longest =  current.get_length
          longest_seq = current
        end
      end
      seq = longest_seq
      longest_non_unique_genes_msa.add_sequence( seq )
    else
      seq = seqs.get_sequence( 0 )
      unique_genes_msa.add_sequence( seq )
    end


    unless IGNORE_SPECIES
      species = species_re.match( seq.get_name )[ 1 ]
    else
      species = "XXXXX"
    end
    unless all_msa_per_species.has_key?( species )
      all_msa_per_species[ species ] = Msa.new
    end
    all_msa_per_species[ species ].add_sequence( seq )

  end

  outfile.close

  w = FastaWriter.new
  w.write( unique_genes_msa, outbase + "_seqs_from_unique_genes.fasta" )
  w.write( longest_non_unique_genes_msa, outbase + "_longest_seqs_from_nonunique_genes.fasta" )

  all_msa_per_species.each_pair do |s,m|
    w = FastaWriter.new
    w.write( m, outbase + "_"  + s + ".fasta" )
  end

end
