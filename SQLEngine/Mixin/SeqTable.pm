=head1 NAME

DBIx::SQLEngine::Mixin::SeqTable

=head1 SYNOPSIS

  # Classes can inherit this behavior if they don't have native sequences
  push @DBIx::SQLEngine::AcmeDB::ISA, 'DBIx::SQLEngine::Mixin::SeqTable';
  
  # Public interface for SeqTable functionality
  $nextid = $sqldb->seq_increment( $table, $field );

  # Housekeeping functions for setup and removal
  $sqldb->seq_create_table();
  $sqldb->seq_insert_record( $table, $field );
  $sqldb->seq_delete_record( $table, $field );
  $sqldb->seq_drop_table();

=head1 DESCRIPTION

This mixin supports SQL database servers which do natively support an auto-incrementing or unique sequence trigger. Instead, a special table is allocated to store sequence values, and queries are used to atomically retrieve and increment the sequence value to ensure uniqueness.

=cut

########################################################################

package DBIx::SQLEngine::Mixin::SeqTable;

use strict;
use Carp;

########################################################################

=head1 REFERENCE

=head2 seq_table_name

Constant 'dbix_sqlengine_seq'.

=cut

use constant seq_table_name => 'dbix_sqlengine_seq';

########################################################################

=head2 seq_create_table

  $sqldb->seq_create_table()

Issues a SQL create table statement to create the sequence table.

=cut

sub seq_create_table {
  my $self = shift;
  my $seq_table = $self->seq_table_name;
  $self->do_create_table( $seq_table, [
    { type => 'text',    name => 'seq_name', length => 48, required => 1 }, 
    { type => 'int',     name => 'seq_value',              required => 1 }, 
    { type => 'primary', name => 'seq_name' }, 
  ] );
  # warn "Created sequence table '$seq_table'";
}

=head2 seq_drop_table

  $sqldb->seq_drop_table()

Issues a SQL drop table statement to remove the sequence table.

=cut

# $sqldb->seq_drop_table();
sub seq_drop_table {
  my $self = shift;
  my $seq_table = $self->seq_table_name;
  $self->do_drop_table( $seq_table );
  # warn "Dropped sequence table '$seq_table'";
}

########################################################################

=head2 seq_insert_record

  $sqldb->seq_insert_record( $table, $field )

Creates a record in the sequence table for a given field in a particular table. 

=cut

# $sqldb->seq_insert_record( $table, $field ); 
sub seq_insert_record {
  my $self = shift;
  my ($table, $field) = @_;
  $self->do_insert(
    table => $self->seq_table_name,
    values => { seq_name => "$table.$field", seq_value => 0, },
  );
}

=head2 seq_delete_record

  $sqldb->seq_delete_record( $table, $field )

Removes the corresponding record in the sequence table.

=cut

# $sqldb->seq_delete_record( $table, $field );
sub seq_delete_record {
  my $self = shift;
  my ($table, $field) = @_;
  $self->do_delete(
    table => $self->seq_table_name,
    criteria => [ 'seq_name = ?', "$table.$field" ],
  );
}

########################################################################

=head2 seq_bootstrap_init

  $sqldb->seq_bootstrap_init( $table, $field ) : $current_value

Scans the designated field in a given table to determine its maximum value, and then stores that in sequence table.

=cut

# $sqldb->seq_bootstrap_init( $table, $field ); 
sub seq_bootstrap_init {
  my $self = shift;
  my ($table, $field) = @_;
  
  my $max = $self->fetch_one_value(
    table => $table,
    columns => "max($field)",
  );
  
  return unless $max;
  
  $self->seq_increment( $table, $field, $max );
}

########################################################################

=head2 seq_fetch_current

  $sqldb->seq_fetch_current( $table, $field ) : $current_value

Fetches the current sequence value.

=cut

# $current_id = $sqldb->seq_fetch_current( $table, $field );
sub seq_fetch_current {
  my $self = shift;
  my ($table, $field) = @_;
  my $seq_table = $self->seq_table_name;
  $self->fetch_one_value(
    table => $seq_table,
    columns => 'seq_value',
    criteria => [ 'seq_name = ?', "$table.$field" ],
  );
}

########################################################################

=head2 seq_increment

  $sqldb->seq_increment( $table, $field ) : $new_value

Increments the sequence, and returns the newly allocated value. 

This is the primary "public" interface of this package. 

If someone else has completed the same increment before we have, our update will have no effect and we'll immeidiately try again and again until successful.

If the table does not yet exist, attempts to create it automatically. 

If the sequence record does not yet exist, attempts to create it automatically.

=cut

# $nextid = $sqldb->seq_increment( $table, $field );
# $nextid = $sqldb->seq_increment( $table, $field, $value);
sub seq_increment {
  my $self = shift;

  my ($table, $field, $next) = @_;

  my $seq_table = $self->seq_table_name;
  my $current;
  eval {
    local $SIG{__DIE__};
    $current = $self->seq_fetch_current( $table, $field );
  };
  if ( my $err = $@ ) {
    eval {
      local $SIG{__DIE__};
      $self->seq_create_table();
    };
    if ( $@ ) {
      confess "Unable to select from sequence table $seq_table: $err\n" . 
	      "Also unable to automatically create sequence table: $@";
    }
  }
  if ( ! defined $current ) {
    $self->seq_insert_record( $table, $field ); 
    $current = $self->seq_bootstrap_init( $table, $field ) || 0;
  }
  
  ATTEMPT: {
    $next = $current + 1 unless ( $next and $next > $current );
    
    return $next if $self->do_update(
      table => $self->seq_table_name,
      values => { seq_value => $next },
      criteria => ['seq_value = ? and seq_name = ?', $current, "$table.$field"]
    );
    
    $current = $self->seq_fetch_current( $table, $field );
    redo ATTEMPT;
  }
}

########################################################################

=head1 SEE ALSO

See L<DBIx::Sequence> for another version of the sequence-table functionality, which greatly inspired this module.



=cut

########################################################################

1;

