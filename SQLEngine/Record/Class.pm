=head1 NAME

DBIx::SQLEngine::Record::Class - Factory for Record Classes

=head1 SYNOPSIS

B<Setup:> Several ways to create a class.

  $sqldb = DBIx::SQLEngine->new( ... );
  
  $class_name = $sqldb->record_class( $table_name, @traits );
  
  $sqldb->record_class( $table_name, $class_name, @traits );

B<Basics:> Common operations on a record.

  $record = $class_name->fetch_record( $primary_key );
  
  @records = $class_name->fetch_select(%clauses)->records;
  
  $record = $class_name->new_with_values(somefield => 'My Value');
  
  print $record->get_values( 'somefield' );
  $record->change_values( somefield => 'New Value' );

  $record->insert_record();
  
  $record->update_record();
  
  $record->delete_record();

=head1 DESCRIPTION

DBIx::SQLEngine::Record::Class is a factory for Record classes.

You can use this package to create a class whose instances represent each of the rows in a SQL database table.

=cut

########################################################################

package DBIx::SQLEngine::Record::Class;
use strict;

use Carp;

use DBIx::SQLEngine::Record::Base;

########################################################################

=head1 CLASS INSTANTIATION

=head2 Subclass Factory

=over 4

=item import

  package My::Record;
  use DBIx::SQLEngine::Record::Class '-isasubclass';
  use DBIx::SQLEngine::Record::Class '-isasubclass', @Traits;

Allows for a simple declaration of inheritance.

=back

=cut

sub import {
  my $factory = shift;

  return unless ( @_ );
  
  if ( $_[0] eq '-isasubclass' ) {
    shift;
    my $base = $factory->base_class_with_traits( @_ );

    my $target_class = ( caller )[0];
    no strict;
    push @{"$target_class\::ISA"}, $base;
  } else {
    croak("Unsupported import '$_[0]'")
  }
}

########################################################################

=head2 Record Class Creation

=over 4

=item new_subclass()

  DBIx::SQLEngine::Record::Class->new_subclass( %options ) : $class_name

Subclass constructor. Accepts a hash of options with the following keys:

=over 4

=item 'name'

If you do not supply a class name, one is generated based on the table name, which must be provided.

If the class name does not contain a "::" package separator, it is prepended
with DBIx::SQLEngine::Record::Auto:: to keep the namespace conflict-free.

=item 'table'

You may provde a DBIx::SQLEngine::Schema::Table object or create the class without it and initialize it later.

=item 'traits'

You may pass a reference to one or more trait names as a "traits" argument.

=back

=item subclass_for_table()

  DBIx::SQLEngine::Record::Class->subclass_for_table( $table, $name, @traits ) : $class_name

Convenience method for common parameters. 
You are expected to provde a DBIx::SQLEngine::Schema::Table object.

=back

Cross-constructors from other objects:

=over 4

=item SQLEngine->record_class()

  $sqldb->record_class( $tablename ) : $class_name
  $sqldb->record_class( $tablename, $name ) : $class_name
  $sqldb->record_class( $tablename, $name, @traits ) : $class_name

Convenience method to create a record class with the given table name.

=item Table->record_class()

  $table->record_class( ) : $class_name
  $table->record_class( $name ) : $class_name
  $table->record_class( $name, @traits ) : $class_name

Convenience method to create a record class for a given table object.

=back

=cut

sub subclass_for_table {
  my ($factory, $table, $classname, @traits) = @_;
  $factory->new_subclass(
    table => $table, name => $classname, traits => \@traits
  )
}

sub new_subclass {
  my ( $factory, %options ) = @_;

  my $base = $factory->base_class_with_traits( $options{traits} );

  my $table = $options{table};
  my $name = $options{name} || do {
    $table or croak("$factory new_subclass requires without a name requires a table");
    $factory->generate_subclass_name_for_table($table);
  };
  $name = "DBIx::SQLEngine::Record::Auto::" . $name unless ( $name =~ /::/ );

  no strict 'refs';
  @{"$name\::ISA"} = $base;

  $name->table( $table ) if ( $table );
  
  return $name;
}

########################################################################

my %generated_names_for_table;
sub generate_subclass_name_for_table {
  my ($factory, $table) = @_;
  my $tname = $table->name;
  my $tsqle = $table->sqlengine;
  my $t_str = "$tname-$tsqle";

  if ( my $names = $generated_names_for_table{ $tname } ) {
    return $tname if ( $names->{ $tname } eq $t_str );
    my $t_index = $tname . "_1";
    until ( $names->{ $t_index } eq $t_str ) { $t_index ++ }
    return $t_index;
  } else {
    $generated_names_for_table{ $tname } = { $tname => $t_str };
    return $tname;
  }
}

########################################################################

########################################################################

=head1 RECORD CLASS TRAITS

Depending on application, there are several different sets of features that one might or might not wish to have available on their record class. 

=head2 Included Trait Classes

The following trait classes are included with this distribution:

=over 4

=item Accessors

Generates methods for getting and setting values in each record object.

=item Cache

Provides a caching layer to avoid repeated selections of the same information.

=item Hooks 

Adds ok_, pre_, and post_ hooks to key methods. Any number of code refs can be registered to be called at key times, by class or for specific instances. 

=back

=cut

########################################################################

=head2 Accessing Packages

=over 4

=item base_class

  $factory->base_class() : $base_class

=item require_package

  $factory->require_package( $package_name )

Uses require() to load the named package.

=item get_trait_package()

  $factory->get_trait_package($subclass) : ($name, $package, $trait)

=back

=cut

sub base_class {
  'DBIx::SQLEngine::Record::Base'
}

sub require_package {
  my ( $factory, $target ) = @_;
  $target =~ s{::}{/}g;
  $target .= ".pm";
  # warn "require $target";
  require $target;
}

# ($name, $package) = Record::Class->get_trait_package($name);
sub get_trait_package {
  my ($factory, $arg) = @_;

  my $name = $arg;
  $name =~ s/.*:://;
  
  my $package = $arg;
  ( $package =~ /::/ ) or $package = "DBIx::SQLEngine::Record::Trait::$package";
  $factory->require_package( $package );

  wantarray ? ( $name, $package ) : $package
}

########################################################################

=head2 Composing Trait Classes

=over 4

=item base_class_with_traits

  $factory->base_class_with_traits() : $base_class
  $factory->base_class_with_traits( @traits ) : $class_name

Instead of forcing use of NEXT, with a slower redispatch method, we're going to build an ad-hod class hierarchy. 
Because some of the methods call SUPER methods, they need to be evaluated repeatedly in each composed subclass. 

=back

=cut

sub base_class_with_traits {
  my $factory = shift;
  my @args = ( @_ == 1 and ref($_[0]) ) ? @{ $_[0] } : @_;
  
  my $package = $factory->base_class();
  my $name = 'Base';

  while ( scalar @args ) {
    my $trait = shift @args;
    my ($t_name, $t_class) = $factory->get_trait_package($trait);
    
    $name .= "_$t_name";
    my $new_class = $factory . "::" . $name;
    
    no strict;
    @{ "$new_class\::ISA" } or eval join "\n",
					"package $new_class;", 
					"\@ISA = qw( $t_class $package );",
					@{$t_class . "::MIXIN"};
    $package = $new_class;
  }
  
  $package;
}

########################################################################

=head2 Trait Subclass Internals

=over 4

=item import_self_trait()

Used by trait packages to construct simple subclasses.

=back

=cut

sub import_self_trait {
  my $factory = shift;

  my $target_class = ( caller )[0];
  my $trait = $target_class;
  $trait =~ s/.*:://;

  my $trait_class = $factory->base_class_with_traits( $trait );

  no strict 'refs';  
  @{ "$target_class\::ISA" } = $trait_class;
}

########################################################################

########################################################################

=head1 SEE ALSO

See L<DBIx::SQLEngine> for the overall interface and developer documentation.

See L<DBIx::SQLEngine::Docs::ReadMe> for general information about
this distribution, including installation and license information.

=cut

########################################################################

1;
