#!/bin/env perl -w

$VERSION = '0.003';

#------------------------------------------------------------------------------
#
# Pod
#
#------------------------------------------------------------------------------

=head1 NAME

html2text.pl - script for generating formatted text from HTML

=head1 SYNOPSIS

    html2text.pl <filename>
    cat <filename> | html2text.pl

=head1 DESCRIPTION

B<html2text.pl> generated simple formatted text from HTML. It uses
HTML::Element to traverse an HTML tree built by HTML::TreeBuilder, and formats
the output text using Text::Format. It is I<very> simple at the moment. The
type of things it does are:

=over 4

=item Headings

All headings are underlined. <H1>s are double underlined. Headings are
numbered, by using the heading levels, and previous heading levels.

=item Paragraphs

Paragraph text is formatted with the paragraph method of Text::Format.

=item Lists

List items are indented by 4 spaces, and preceded with an asterisk.

=item Definition Lists

<DT>s are intented by 4 spaces; <DD>s are indented by 8 spaces.

=back

=head1 PREREQUISITES

Text::Format
HTML::TreeBuilder

=head1 OSNAMES

any

=head1 AUTHOR

Ave Wrigley E<lt>Ave.Wrigley@itn.co.ukE<gt>

=head1 COPYRIGHT

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SCRIPT CATEGORIES

Web

=cut

#------------------------------------------------------------------------------
#
# End of pod
#
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
require 5.004;

#------------------------------------------------------------------------------
#
# CPAN modules
#
#------------------------------------------------------------------------------

use Text::Format;
use HTML::TreeBuilder;

#------------------------------------------------------------------------------
#
# Constants
#
#------------------------------------------------------------------------------

use constant IGNORE_TEXT => 1;

#------------------------------------------------------------------------------
#
# Public global varables
#
#------------------------------------------------------------------------------

use vars qw(
    $html_tree
    $text_formatter
);

#------------------------------------------------------------------------------
#
# set autoflushing
#
#------------------------------------------------------------------------------

$|++;

#------------------------------------------------------------------------------
#
# BEGIN block - create global objects
#
#------------------------------------------------------------------------------

BEGIN {
    $html_tree = new HTML::TreeBuilder;
    $text_formatter = new Text::Format;
    $text_formatter->firstIndent( 0 );
}

#------------------------------------------------------------------------------
#
# prefixes to convert tags into - some are converted bachk to Text::Format
# formatting later
#
#------------------------------------------------------------------------------

my %prefix = (
    'li'        => '* ',
    'dt'        => '+ ',
    'dd'        => '- ',
);

my %underline = (
    'h1'        => '+',
    'h2'        => '=',
    'h3'        => '-',
    'h4'        => '-',
    'h5'        => '-',
    'h6'        => '-',
);

my @heading_number = ( 0, 0, 0, 0, 0, 0 );

#------------------------------------------------------------------------------
#
# get_text - get all the text under a node
#
#------------------------------------------------------------------------------

sub get_text
{
    my $this = shift;
    my $text = '';

    defined( $this->content ) || return( '' );
    # iterate though my children ...
    for my $child ( @{ $this->content } )
    {
        # if the child is also non-text ...
        if ( ref( $child ) )
        {
            # traverse it ...
            $child->traverse(
                # traveral callback
                sub {
                    my( $node, $startflag, $depth ) = @_;
                    # only visit once
                    return 0 unless $startflag;
                    # if it is non-text ...
                    if ( ref( $node ) )
                    {
                        # recurse get_text
                        $text .= get_text( $node );
                    }
                    # if it is text
                    else
                    {
                        # add it to $text
                        $text .= $node if $node =~ /\S/;
                    }
                    return 0;
                },
                not IGNORE_TEXT
            );
        }
        # if it is text
        else
        {
            # add it to $text
            $text .= $child if $child =~ /\S/;
        }
    }
    return $text;
}

#------------------------------------------------------------------------------
#
# get_paragraphs - routine for generating an array of paras from a given node
#
#------------------------------------------------------------------------------

sub get_paragraphs
{
    my $this = shift;

    # array to save paragraphs in
    my @paras = ();
    # avoid -w warning for .= operation on undefined
    $paras[ 0 ] = '';

    defined( $this->content ) || return( @paras );
    # iterate though my children ...
    for my $child ( @{ $this->content } )
    {
        # if the child is also non-text ...
        if ( ref( $child ) )
        {
            # traverse it ...
            $child->traverse(
                # traveral callback
                sub {
                    my( $node, $startflag, $depth ) = @_;
                    # only visit once
                    return 0 unless $startflag;
                    # if it is non-text ...
                    if ( ref( $node ) )
                    {
                        # if it is a list element ...
                        if ( $node->tag =~ /^(?:li|dd|dt)$/ )
                        {
                            # recurse get_paragraphs
                            my @new_paras = get_paragraphs( $node );
                            # pre-pend appropriate prefix for list
                            $new_paras[ 0 ] =
                                $prefix{ $node->tag } . $new_paras[ 0 ]
                            ;
                            # and update the @paras array
                            @paras = ( @paras, @new_paras );
                            # and traverse no more
                            return 0;
                        }
                        else
                        {
                            # any other element, just traverse
                            return 1;
                        }
                    }
                    else
                    {
                        # add text to the current paragraph ...
                        $paras[ $#paras ] = 
                            join( ' ', $paras[ $#paras ], $node )
                            if $node =~ /\S/
                        ;
                        # and recurse no more
                        return 0;
                    }
                },
                not IGNORE_TEXT
            );
        }
        else
        {
            # add test to current paragraph ...
            $paras[ $#paras ] = join( ' ', $paras[ $#paras ], $child )
                if $child =~ /\S/
            ;
        }
    }
    return @paras;
}

#------------------------------------------------------------------------------
#
# Main
#
#------------------------------------------------------------------------------

# parse the STDIN or ARGV

warn "Starting $0 ...\n";
$html_tree->parse( join( '', <> ) );

# main tree traversal routine

$html_tree->traverse(
    sub {
        my( $node, $startflag, $depth ) = @_;
        # ignore what's in the <HEAD>
        return 0 if ref( $node ) and $node->tag eq 'head';
        # only visit nodes once
        return 0 unless $startflag;
        # if this node is non-text ...
        if ( ref $node )
        {
            # if this is a para  ...
            if ( $node->tag eq 'p' )
            {
                # iterate sub-paragraphs (including lists) ...
                for ( get_paragraphs( $node ) )
                {
                    # if it is a <LI> ...
                    if ( /^\* / )
                    {
                        # indent first line by 4, rest by 6
                        $text_formatter->firstIndent( 4 );
                        $text_formatter->bodyIndent( 6 );
                    }
                    # if it is a <DT> ...
                    elsif ( s/^\+ // )
                    {
                        # set left margin to 4
                        $text_formatter->leftMargin( 4 );
                    }
                    # if it is a <DD> ...
                    elsif ( s/^- // )
                    {
                        # set left margin to 8
                        $text_formatter->leftMargin( 8 );
                    }
                    # print formatted paragraphs ...
                    print $text_formatter->paragraphs( $_ );
                    # and reset formatter defaults
                    $text_formatter->leftMargin( 0 );
                    $text_formatter->firstIndent( 0 );
                    $text_formatter->bodyIndent( 0 );
                }
                print "\n";
                return 0;
            }
            # if this is a heading ...
            elsif ( $node->tag =~ /^h(\d)/ )
            {
                # get the heading level ...
                my $level = $1;
                # increment the number for this level ...
                $heading_number[ $level ]++;
                # reset lower level heading numbers ...
                for ( $level+1 .. $#heading_number )
                {
                    $heading_number[ $_ ] = 0;
                }
                # create heading number string
                my $heading_number = join( 
                    '.', 
                    @heading_number[ 1 .. $level ]
                );
                # generate heading from number string and heading text ...
                # my $text = "$heading_number " . get_text( $node );
                my $text = get_text( $node ) . "\n";
                # underline it with the appropriate underline character ...
                $text =~ s{
                        (.*)
                    }
                    {
                        "$1\n" . $underline{ $node->tag } x length( $1 )
                    }gex
                ;
                print $text;
                return 0;
            }
            return 1;
        }
        # if it is text ...
        else
        {
            return 0 unless $node =~ /\S/;
            print $text_formatter->format( $node );
            return 0;
        }
    },
    not IGNORE_TEXT
);

#------------------------------------------------------------------------------
#
# End of main
#
#------------------------------------------------------------------------------
