=head1 NAME

DBIx::SQLEngine::Record::Set - Array of Record Objects

=head1 SYNOPSIS

  use DBIx::SQLEngine::Record::Set;

  $record_set = DBIx::SQLEngine::Record::Set->new( @records );

  $record_set = $record_class->fetch_select( criteria => { status => 2 } );
  
  print "Found " . $record_set->count() . " records";

  $record_set->filter( { 'status' => 'New' } );
  $record_set->sort( 'creation_date' );
  
  foreach ( 0 .. $record_set->count() ) { 
    print $record_set->record( $_ )->name();
  }
  
  foreach ( $record_set->range_records( 11, 20 ) ) { 
    print $_->name();
  }


=head1 DESCRIPTION

This package is not yet complete.

The base implementation of RecordSet is an array of Record references.

=cut

########################################################################

package DBIx::SQLEngine::Record::Set;
use strict;

use Carp;

use DBIx::SQLEngine::Record::Class;

########################################################################

=head2 Constructor 

=over 4

=item new()

  $class->new ( @records ) : $recordset

Array constructor.

=back

=cut

# $rs = DBIx::SQLEngine::Record::Set->new( @records );
sub new {
  my $callee = shift;
  my $package = ref $callee || $callee;

  my @records = @_;
  bless \@records, $package;
}

########################################################################

=head2 Contents 

=over 4

=item init()

  $recordset->init ( @records ) 

Array content setter.

=item records()

  $rs->records() : @records

Array content accessor.

=back

=cut

# $rs->init( @records );
sub init {
  my $self = shift;
  
  @$self = ( scalar @_ == 1 and ref($_[0]) eq 'ARRAY' ) ? @{ $_[0] } : @_;
}

# @records = $rs->records();
sub records {
  my $records = shift;
  @$records
}

########################################################################

=head2 Positional Access 

=over 4

=item * 

$count = $rs->count();

=item * 

$record = $rs->record( $position );

Return the record in the indicated position in the array.

=item * 

$record = $rs->last_record();

Return the last record in the array.

=back

=cut

# $count = $rs->count();
sub count {
  my $self = shift;
  scalar @$self;
}

# $record = $rs->record( $position );
sub record {
  my $self = shift;
  my $position = shift;
  return unless ( length $position and $position !~ /\D/ and $position <= $#$self);
  $self->[ $position ];
}

# $record = $rs->last_record();
sub last_record {
  my $self = shift;
  return unless $self->count;
  $self->record( $self->count - 1 );
}

########################################################################

=head2 Positional Subsets 

=over 4

=item * 

$clone = $rs->range_set( $start_pos, $stop_pos );

Return a copy of the current set containing only those records at or between the start and stop positions.

=item * 

@records = $rs->range_records( $start_pos, $stop_pos );

Return the records at or between the start and stop positions.

=back

=cut

# $clone = $rs->range_set( $start_pos, $stop_pos );
sub range_set {
  my $self = shift;
  my ( $start, $end ) = @_;
  if ( $start < 0 ) { $start = 0 }
  if ( $end > $#$self ) { $end = $#$self }
   
  $self->new( @{$self}[ $start .. $end ] );
}

# @records = $rs->range_records( $start_pos, $stop_pos );
sub range_records {
  my $self = shift;
  my ( $start, $end ) = @_;
  if ( $start < 0 ) { $start = 0 }
  if ( $end > $#$self ) { $end = $#$self }
   
  @{$self}[ $start .. $end ];
}

########################################################################

=head2 Sorting

=over 4

=item * 

$rs->sort( @fieldnames );

Sort the contents of the set.

=item * 

$clone = $rs->sorted_set( @fieldnames );

Return a sorted copy of the current set.

=item * 

@records = $rs->sorted_records( @fieldnames );

Return the records from the current set, in sorted order.

=back

=cut

# $rs->sort( @fieldnames );
sub sort {
  my $self = shift;
  local @_ = @{ $_[0] } if ( scalar @_ == 1 and ref $_[0] eq 'ARRAY' );
  require Data::Sorting;
  Data::Sorting::sort_array(@$self, @_);
}

# $clone = $rs->sorted_set( @fieldnames );
sub sorted_set {
  my $self = shift;
  my $clone = $self->new( @$self );
  $clone->sort( @_ );
  return $clone;
}

# @records = $rs->sorted_records( @fieldnames );
sub sorted_records {
  my $self = shift;
  my $clone = $self->new( @$self );
  $clone->sort( @_ );
  $clone->records();
}

sub reverse {
  my $rs = shift;
  @$rs = reverse @$rs;
}

########################################################################

=head2 Criteria Matching

=over 4

=item * 

$rs->filter( $criteria );

Remove non-matching records from the set.

=item * 

$clone = $rs->filtered_set( $criteria );

Return a set containing only the matching records from the current set.

=item * 

@records = $rs->filtered_records( $criteria );

Return the matching records from the current set.

=back

=cut

use DBIx::SQLEngine::Criteria qw( new_group_from_values );

# $rs->filter( $criteria );
sub filter {
  my $self = shift;
  
  my $criteria = shift
	or return;
  if (ref $criteria eq 'ARRAY') { 
    $criteria = new_group_from_values(@$criteria);
  } elsif (ref $criteria eq 'HASH') {
    $criteria = DBO::Criteria->new_from_hashref($criteria);
  } elsif (ref $criteria eq 'CODE') {
    @$self = grep { $criteria->( $_ ) } @$self;
    return;
  } 
  
  @$self = $criteria->matchers($self);
}

# $clone = $rs->filtered_set( $criteria );
sub filtered_set {
  my $self = shift;
  my $clone = $self->new( @$self );
  $clone->filter( @_ );
  return $clone;
}

# @records = $rs->filtered_records( $criteria );
sub filtered_records {
  my $self = shift;
  my $clone = $self->new( @$self );
  $clone->filter( @_ );
  $clone->records();
}

########################################################################

# $numeric = $rs->sum( $fieldname );
sub sum {
  my $rs = shift;  
  my $field = shift;
  my $sum = 0;
  foreach ( $rs->records ) {
    $sum += $_->$field();
  }
  return $sum;
}

########################################################################

# @results = $rs->visit_sub( $subref, @$leading_args, @$leading_args );
sub visit_sub {
  my $rs = shift;  
  my $subref = shift;
  my @pre_args = map { ref($_) ? @$_ : defined($_) ? $_ : () } shift;
  my @post_args = map { ref($_) ? @$_ : defined($_) ? $_ : () } shift;
  my @result;
  foreach my $record ( $rs->records ) {
    push @result, $subref->( @pre_args, $record, @post_args )
  }
  return @result;
}

########################################################################

# $rs->push_unique_records( @records );
sub push_unique_records {
  my $rs = shift;
  my %record_ids = map { $_->id => 1 } $rs->records;
  push @$rs, grep { ! ( $record_ids{ $_->id } ++ ) } @_
}

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;

__END__








=head1 CHANGES

2001-06-29 Moved to DBIx::DBO2 namespace.

2001-04-10 Added last_record. 

2000-12-13 Substantial revisions. Moved to EBiz::Database namespace. 

2000-12-01 Ed: Created. 

=cut







=head2 Class and IDs

=over 4

=item * 

$rs = DBIx::SQLEngine::Record::Set->new_class_ids( $class, @ids );

=item * 

$rs->init_class_ids( $class, @ids );

=item * 

( $class, @ids ) = $rs->class_ids();

=back

=head2 Conversions

Each of the below returns a RecordSet blessed into a particular subclass. Returns the original object if it is already of that subclass, or returns a cloned and converted copy.

=over 4

=item * 

@data = $rs->raw();

Returns the contents of the RecordSet as stored internally within the object. Results are dependent on which subclass is in use.

=item * 

$rs = $rs->as_RecordArray;

INCOMPLETE

=item * 

$clone = $rs->as_IDArray;

INCOMPLETE

=item * 

$clone = $rs->as_IDString;

INCOMPLETE

=back

# $rs = DBIx::SQLEngine::Record::Set->new_class_ids( $class, @ids );
sub new_ids {
  my $callee = shift;
  my $package = ref $callee || $callee;
  
  my $self = [];
  bless $self, $package;
  $self->init_class_ids( @_ );
  return $self;
}

# $rs->init_ids( $class, @ids );
sub init_ids {
  my $self = shift;
  my $class = shift;
  
  @$self = map { $class->fetch_id( $_ ) } @_;
}

# @records = $rs->class_ids();
sub class_ids {
  my $self = shift;
  my $class = ref( $self->[0] );
  return $class, map { $_->{id} } @$self;
}

###

sub raw {
  my $self = shift;
  if ( scalar @_ ) {
    @$self = @_;
  } else {
    @$self;
  }
}
# 
# sub as_RecordArray {
#   my $self = shift;
# }
# 
# sub as_IDArray {
#   my $self = shift;
#   EBiz::Database::RecordSet::IDArray->new( $self->records );
# }
# 
# sub as_IDString {
#   my $self = shift;
#   EBiz::Database::RecordSet::IDString->new( $self->records );
# }


