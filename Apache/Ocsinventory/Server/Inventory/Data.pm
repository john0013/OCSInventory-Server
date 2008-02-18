###############################################################################
## OCSINVENTORY-NG 
## Copyleft Pascal DANEK 2008
## Web : http://www.ocsinventory-ng.org
##
## This code is open source and may be copied and modified as long as the source
## code is always made freely available.
## Please refer to the General Public Licence http://www.gnu.org/ or Licence.txt
################################################################################
package Apache::Ocsinventory::Server::Inventory::Data;

use strict;

require Exporter;

our @ISA = qw /Exporter/;

our @EXPORT = qw / 
  _init_map 
  _get_bind_values 
  _has_changed 
  _get_parser_ForceArray 
/;

use Apache::Ocsinventory::Map;
use Apache::Ocsinventory::Server::System qw / :server /;

sub _init_map{
  my ($sectionsMeta, $sectionsList) = @_;
  my $section;
  my @bind_num;
  my $field;
  my $fields_string;
  
  # Parse every section
  for $section (keys(%DATA_MAP)){
    # Field array (from data_map field hash keys), filtered fields and cached fields
    $sectionsMeta->{$section}->{field_arrayref} = [];
    $sectionsMeta->{$section}->{field_filtered} = [];
    $sectionsMeta->{$section}->{field_cached} = [];
    ##############################################
    # Don't process the non-auto-generated sections
    next if !$DATA_MAP{$section}->{auto};
    $sectionsMeta->{$section}->{multi} = 1 if $DATA_MAP{$section}->{multi};
    $sectionsMeta->{$section}->{mask} = $DATA_MAP{$section}->{mask};
    $sectionsMeta->{$section}->{delOnReplace} = 1 if $DATA_MAP{$section}->{delOnReplace};
    $sectionsMeta->{$section}->{writeDiff} = 1 if $DATA_MAP{$section}->{writeDiff};
    $sectionsMeta->{$section}->{cache} = 1 if $DATA_MAP{$section}->{cache};
     
    # Parse fields of the current section
    for $field ( keys(%{$DATA_MAP{$section}->{fields}} ) ){
      if(!$DATA_MAP{$section}->{fields}->{$field}->{noSql}){
        push @{$sectionsMeta->{$section}->{field_arrayref}}, $field;
        $sectionsMeta->{$section}->{noSql} = 1 unless $sectionsMeta->{$section}->{noSql};
      }
      if($DATA_MAP{$section}->{fields}->{$field}->{filter}){
        next unless $ENV{OCS_OPT_INVENTORY_FILTER_ENABLED};
        push @{$sectionsMeta->{$section}->{field_filtered}}, $field;
        $sectionsMeta->{$section}->{filter} = 1 unless $sectionsMeta->{$section}->{filter};
      }
      if($DATA_MAP{$section}->{fields}->{$field}->{cache}){
        next unless $ENV{OCS_OPT_INVENTORY_CACHE_ENABLED};
        push @{$sectionsMeta->{$section}->{field_cached}}, $field;
        $sectionsMeta->{$section}->{cache} = 1 unless $sectionsMeta->{$section}->{cache};
      }
    }
    # Build the "DBI->prepare" sql insert string 
    $fields_string = join ',', ('HARDWARE_ID', @{$sectionsMeta->{$section}->{field_arrayref}});
    $sectionsMeta->{$section}->{sql_insert_string} = "INSERT INTO $section($fields_string) VALUES(";
    for(0..@{$sectionsMeta->{$section}->{field_arrayref}}){
      push @bind_num, '?';
    }
    
    $sectionsMeta->{$section}->{sql_insert_string}.= (join ',', @bind_num).')';
    @bind_num = ();
    # Build the "DBI->prepare" sql select string 
    $sectionsMeta->{$section}->{sql_select_string} = "SELECT ID,$fields_string FROM $section 
      WHERE HARDWARE_ID=? ORDER BY ".$DATA_MAP{$section}->{sortBy};
    # Build the "DBI->prepare" sql deletion string 
    $sectionsMeta->{$section}->{sql_delete_string} = "DELETE FROM $section WHERE HARDWARE_ID=? AND ID=?";
    # to avoid many "keys"
    push @$sectionsList, $section;
  }
}

sub _get_bind_values{
  my ($refXml, $sectionMeta, $arrayToFeed) = @_;
  for ( @{ $sectionMeta->{field_arrayref} } ) {
    if(defined($refXml->{$_})){
      push @$arrayToFeed, $refXml->{$_};
    }
    else{
      push @$arrayToFeed, '';
    }
  }
}

sub _get_parser_ForceArray{
  my $arrayRef = shift;
  for my $section (keys(%DATA_MAP)){
    # Feed the multilines section array in order to parse xml correctly
    push @{ $arrayRef }, uc $section if $DATA_MAP{$section}->{multi};
  }
}

sub _has_changed{
  my $section = shift;
  my $result = $Apache::Ocsinventory::CURRENT_CONTEXT{'XML_ENTRY'};
  
  # Check checksum to know if section has changed
  if( defined($result->{CONTENT}->{HARDWARE}->{CHECKSUM}) ){
    return $DATA_MAP{$section}->{mask} & $result->{CONTENT}->{HARDWARE}->{CHECKSUM};
  }
  else{
    return 1;
  }
}
1;