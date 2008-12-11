#!/usr/bin/env ruby

require 'test/unit'
require 'wiki_creole'

class TC_WikiCreole < Test::Unit::TestCase

  $strict = false
  
  #-----------------------------------------------------------------------------
  # This first section is the low level method sanity tests.

  def test_strip_leading_and_trailing_eq_and_whitespace
    assert_equal "head", WikiCreole.strip_leading_and_trailing_eq_and_whitespace("==head")
    assert_equal "head", WikiCreole.strip_leading_and_trailing_eq_and_whitespace(" == head")
    assert_equal "head", WikiCreole.strip_leading_and_trailing_eq_and_whitespace("head ==")
    assert_equal "head", WikiCreole.strip_leading_and_trailing_eq_and_whitespace("head == ")
    assert_equal "head", WikiCreole.strip_leading_and_trailing_eq_and_whitespace("head  ")
    assert_equal "head", WikiCreole.strip_leading_and_trailing_eq_and_whitespace("  head")
    assert_equal "head", WikiCreole.strip_leading_and_trailing_eq_and_whitespace("  head  ")
  end
  
  def test_strip_list
    assert_equal "`head", WikiCreole.strip_list(" *head")
    assert_equal "\n`head", WikiCreole.strip_list("\n *head")
    assert_equal "`**head", WikiCreole.strip_list("***head")
  end
  
  def test_chunk_filter_lambdas
    assert_equal "a string with a  in it", WikiCreole.filter_string_x_with_chunk_filter_y("a string with a : in it", :ip)
    assert_equal "a string with a newline", WikiCreole.filter_string_x_with_chunk_filter_y("a string with a newline\n", :p)
    assert_equal "a string with a newline", WikiCreole.filter_string_x_with_chunk_filter_y("a string with a newline\n", :dd)
    assert_equal "", WikiCreole.filter_string_x_with_chunk_filter_y("a non-blank string", :blank)
    
    #special... uses strip_list function inside the lamda function
    assert_equal "`head", WikiCreole.filter_string_x_with_chunk_filter_y(" *head", :ul)
    assert_equal "head", WikiCreole.filter_string_x_with_chunk_filter_y("head == ", :h5)
  end
  
  def test_init
    WikiCreole.init
    assert_equal 1, 1
  end
  
  def test_sub_chunk_for
    WikiCreole.init
    str = "//Hello// **Hello**"
    assert_equal :p, WikiCreole.get_sub_chunk_for(str, :top, 0)
    assert_equal :em, WikiCreole.get_sub_chunk_for(str, :p, 0)
    assert_equal :plain, WikiCreole.get_sub_chunk_for(str, :p, 9)
    assert_equal :strong, WikiCreole.get_sub_chunk_for(str, :p, 10)
  end
  
  def test_strong
    s = WikiCreole.creole_parse("**Hello**")
    assert_equal "<p><strong>Hello</strong></p>\n\n", s
  end
  
  def test_italic
    s = WikiCreole.creole_parse("//Hello//")
    assert_equal "<p><em>Hello</em></p>\n\n", s
  end
  
  def test_italic_bold_with_no_spaces
    s = WikiCreole.creole_parse("//Hello//**Hello**")
    assert_equal "<p><em>Hello</em><strong>Hello</strong></p>\n\n", s
  end
  
  def test_italic_bold_with_a_space_in_the_middle
    s = WikiCreole.creole_parse("//Hello// **Hello**")
    assert_equal "<p><em>Hello</em> <strong>Hello</strong></p>\n\n", s
  end
  
  def test_two_paragraph_italic_bold_with_a_space_in_the_middle
    s = WikiCreole.creole_parse("//Hello// **Hello**\n\n//Hello// **Hello**")
    assert_equal "<p><em>Hello</em> <strong>Hello</strong></p>\n\n<p>" +
      "<em>Hello</em> <strong>Hello</strong></p>\n\n", s
  end
  
  def test_link_with_a_page_name
    s = WikiCreole.creole_parse("the site http://www.yahoo.com/page.html is a site")
    assert_equal %Q{<p>the site <a href="http://www.yahoo.com/page.html">http://www.yahoo.com/page.html</a> is a site</p>\n\n}, s
  end
  
  def test_link_with_a_trailing_slash
    # This test caught a bug in the initial parser, so I changed the ilink
    # :stops regex so it worked.
    s = WikiCreole.creole_parse("the site http://www.yahoo.com/ is a site")
    assert_equal %Q{<p>the site <a href="http://www.yahoo.com/">http://www.yahoo.com/</a> is a site</p>\n\n}, s
  end
  
  def test_escaped_url
    # This behavior is wrong.  If you move the tilda to the
    # beginning of the http, where it makes more sense, it breaks.  Without
    # negative lookback assertions it may be the best we can do without
    # significanly hampering performance.
    s = WikiCreole.creole_parse("the site http:~//www.yahoo.com/ is a site")
    assert_equal %Q{<p>the site http://www.yahoo.com/ is a site</p>\n\n}, s
  end
  
  #-----------------------------------------------------------------------------
  # Test the links
  
  def test_link_with_text
    markup = "This is a paragraph with a [[ link | some link ]].\nCheck it out."
    goodhtml = %Q{<p>This is a paragraph with a <a href="link">some link</a>.\nCheck it out.</p>\n\n}
    
    assert_equal goodhtml, WikiCreole.creole_parse(markup)
    
  end
  
  def test_link_with_no_text
    markup = "This is a paragraph with a [[ link ]].\nCheck it out."
    goodhtml = %Q{<p>This is a paragraph with a <a href="link">link</a>.\nCheck it out.</p>\n\n}
    
    assert_equal goodhtml, WikiCreole.creole_parse(markup)
    
  end
  
  def test_user_supplied_creole_link_function
    
    uppercase = Proc.new {|s| 
      s.upcase!
      s
    }
    WikiCreole.creole_link(uppercase)
    
    markup = "This is a paragraph with an uppercased [[ link ]].\nCheck it out."
    goodhtml = %Q{<p>This is a paragraph with an uppercased <a href="LINK">link</a>.\nCheck it out.</p>\n\n}
    
    assert_equal goodhtml, WikiCreole.creole_parse(markup)
    
    # set the link function back to being nil so that the rest of the tests
    # are not affected by the custom link function
    WikiCreole.creole_link(nil)

  end
  
  def test_puts_existing_creole_tags
    tags = WikiCreole.creole_tag("suppress_puts")
    assert tags.index(/u: open\(<u>\) close\(<\/u>\)/)
  end
  
  def test_custom_creole_tag
    WikiCreole.creole_tag(:p, :open, "<p class=special>")

    markup = "This is a paragraph."
    goodhtml = "<p class=special>This is a paragraph.</p>\n\n"

    assert_equal goodhtml, WikiCreole.creole_parse(markup)
    WikiCreole.creole_tag(:p, :open, "<p>")
  end
  
  def test_user_supplied_plugin_function
    uppercase = Proc.new {|s| 
      s.upcase!
      s
    }
    WikiCreole.creole_plugin(uppercase)
    
    markup = "This is a paragraph with an uppercasing << plugin >>.\nCheck it out."
    goodhtml = %Q{<p>This is a paragraph with an uppercasing  PLUGIN .\nCheck it out.</p>\n\n}
    
    assert_equal goodhtml, WikiCreole.creole_parse(markup)
    
    # set the link function back to being nil so that the rest of the tests
    # are not affected by the custom link function
    WikiCreole.creole_plugin(nil)
  end

  #-----------------------------------------------------------------------------
  # Below here are all the file based tests.  They read the .markup file,
  # parse it, then validate that it matches the pre-existing .html file.
  
  def test_amp
    run_testfile("amp")
  end
  
  def test_block
    run_testfile("block")
  end
  
  def test_escape
    run_testfile("escape")
  end
  
  def test_inline
    run_testfile("inline")
  end
  
  def test_specialchars
    run_testfile("specialchars")
  end
  
  def test_jsp_wiki
    # This test was found on the Creole website.  I had to hand-tweak it a bit
    # for it to make sense for our paticular settings, however, the fundamentals
    # are the same as they were in the original test.
    run_testfile("jsp_wiki")    
  end
  
  def run_testfile(name)
    name = "test_" + name
    markup = File.read("./test/#{name}.markup")
    html = File.read("./test/#{name}.html")
    parsed = WikiCreole.creole_parse(markup)
    #write_file("./test/#{name}.processed", parsed) if name.index(/jsp/)
    assert_equal html, parsed
  end
  
  def write_file(filename, data)
    f = File.new(filename, "w")
    f.write(data)
    f.close
  end
  
  #---------------------------------------------------------------------
  # The following tests are adapted from http://github.com/larsch/creole/tree/master and were written by Lars Christensen
  
  def test_larsch_bold
    # Creole1.0: Bold can be used inside paragraphs
    tc "<p>This <strong>is</strong> bold</p>\n\n", "This **is** bold"
    tc "<p>This <strong>is</strong> bold and <strong>bold</strong>ish</p>\n\n", "This **is** bold and **bold**ish"

    # Creole1.0: Bold can be used inside list items
    html = "
    <ul>
        <li>This is <strong>bold</strong></li>
    </ul>
    "
    tc html, "* This is **bold**"

    # Creole1.0: Bold can be used inside table cells
    html = "
    <table>
        <tr>
            <td>This is <strong>bold</strong></td>
        </tr>
    </table>
    
    "
    tc html, "|This is **bold**|"

    # Creole1.0: Links can appear inside bold text:
    tc("<p>A bold link: <strong><a href=\"http://wikicreole.org/\">http://wikicreole.org/</a> nice!</strong></p>\n\n",
        "A bold link: **http://wikicreole.org/ nice!**")

    # Creole1.0: Bold will end at the end of paragraph
    tc "<p>This <strong>is bold</strong></p>\n\n", "This **is bold"

    # Creole1.0: Bold will end at the end of list items
    html = "
    <ul>
        <li>Item <strong>bold</strong></li>
        <li>Item normal</li>
    </ul>
    "
    tc html, "* Item **bold\n* Item normal"

    # Creole1.0: Bold will end at the end of table cells
    html = "
    <table>
        <tr>
            <td>Item <strong>bold</strong></td>
            <td>Another <strong>bold</strong></td>
        </tr>
    </table>
    
    "
    tc html, "|Item **bold|Another **bold"

    # Creole1.0: Bold should not cross paragraphs
    tc("<p>This <strong>is</strong></p>\n\n<p>bold<strong> maybe</strong></p>\n\n",
       "This **is\n\nbold** maybe")

    # Creole1.0-Implied: Bold should be able to cross a single line break
    tc "<p>This <strong>is\nbold</strong></p>\n\n", "This **is\nbold**"
  end

  def test_larsch_italic
    # Creole1.0: Italic can be used inside paragraphs
    tc("<p>This <em>is</em> italic</p>\n\n",
       "This //is// italic")
    tc("<p>This <em>is</em> italic and <em>italic</em>ish</p>\n\n",
       "This //is// italic and //italic//ish")

    # Creole1.0: Italic can be used inside list items
    html = "
    <ul>
        <li>This is <em>italic</em></li>
    </ul>
    "
    tc html, "* This is //italic//"

    # Creole1.0: Italic can be used inside table cells
    html = "
    <table>
        <tr>
            <td>This is <em>italic</em></td>
        </tr>
    </table>
    
    "
    tc html, "|This is //italic//|"

    # Creole1.0: Links can appear inside italic text:
    tc("<p>A italic link: <em><a href=\"http://wikicreole.org/\">http://wikicreole.org/</a> nice!</em></p>\n\n",
       "A italic link: //http://wikicreole.org/ nice!//")

    # Creole1.0: Italic will end at the end of paragraph
    tc "<p>This <em>is italic</em></p>\n\n", "This //is italic"

    # Creole1.0: Italic will end at the end of list items
    html = "
    <ul>
        <li>Item <em>italic</em></li>
        <li>Item normal</li>
    </ul>
    "
    tc html, "* Item //italic\n* Item normal"

    # Creole1.0: Italic will end at the end of table cells
    html = "
    <table>
        <tr>
            <td>Item <em>italic</em></td>
            <td>Another <em>italic</em></td>
        </tr>
    </table>
    
    "
    tc html, "|Item //italic|Another //italic"

    # Creole1.0: Italic should not cross paragraphs
    tc("<p>This <em>is</em></p>\n\n<p>italic<em> maybe</em></p>\n\n",
       "This //is\n\nitalic// maybe")

    # Creole1.0-Implied: Italic should be able to cross lines
    tc "<p>This <em>is\nitalic</em></p>\n\n", "This //is\nitalic//"
  end

  def test_larsch_bold_italics
    # Creole1.0: By example
    tc "<p><strong><em>bold italics</em></strong></p>\n\n", "**//bold italics//**"

    # Creole1.0: By example
    tc "<p><em><strong>bold italics</strong></em></p>\n\n", "//**bold italics**//"

    # Creole1.0: By example
    tc "<p><em>This is <strong>also</strong> good.</em></p>\n\n", "//This is **also** good.//"
  end
  
  def test_larsch_headings
    # Creole1.0: Only three differed sized levels of heading are required.
    tc "<h1>Heading 1</h1>\n\n", "= Heading 1 ="
    tc "<h2>Heading 2</h2>\n\n", "== Heading 2 =="
    tc "<h3>Heading 3</h3>\n\n", "=== Heading 3 ==="
    unless $strict
      tc "<h4>Heading 4</h4>\n\n", "==== Heading 4 ===="
      tc "<h5>Heading 5</h5>\n\n", "===== Heading 5 ====="
      tc "<h6>Heading 6</h6>\n\n", "====== Heading 6 ======"
    end

    # Creole1.0: Closing (right-side) equal signs are optional
    tc "<h1>Heading 1</h1>\n\n", "=Heading 1"
    tc "<h2>Heading 2</h2>\n\n", "== Heading 2"
    tc "<h3>Heading 3</h3>\n\n", " === Heading 3"

    # Creole1.0: Closing (right-side) equal signs don't need to be balanced and don't impact the kind of heading generated
    tc "<h1>Heading 1</h1>\n\n", "=Heading 1 ==="
    tc "<h2>Heading 2</h2>\n\n", "== Heading 2 ="
    tc "<h3>Heading 3</h3>\n\n", " === Heading 3 ==========="
    
    # Creole1.0: Whitespace is allowed before the left-side equal signs.
    # TODO XXX: These don't work in this version of the parser
    #tc "<h1>Heading 1</h1>\n\n", "\t= Heading 1 ="
    #tc "<h2>Heading 2</h2>\n\n", " \t == Heading 2 =="
    
    # Creole1.0: Only white-space characters are permitted after the closing equal signs.
    tc "<h1>Heading 1</h1>\n\n", " = Heading 1 =   "
    tc "<h2>Heading 2</h2>\n\n", " == Heading 2 ==  \t  "

    # !!Creole1.0 doesn't specify if text after closing equal signs
    # !!becomes part of the heading or invalidates the entire heading.
    # tc "<p> == Heading 2 == foo</p>\n\n", " == Heading 2 == foo"
    unless $strict
      tc "<h2>Heading 2 == foo</h2>\n\n", " == Heading 2 == foo"
    end
    
    # Creole1.0-Implied: Line must start with equal sign
    tc "<p>foo = Heading 1 =</p>\n\n", "foo = Heading 1 ="
  end
  
  # left off adding Lars' tests here... will do more as time allows.
  
  # def test_larsch_links
    # # Creole1.0: Links
    # tc "<p><a href=\"link\">link</a></p>", "[[link]]"

    # # Creole1.0: Links can appear in paragraphs (i.e. inline item)
    # tc "<p>Hello, <a href=\"world\">world</a></p>", "Hello, [[world]]"
    
    # # Creole1.0: Named links
    # tc "<p><a href=\"MyBigPage\">Go to my page</a></p>", "[[MyBigPage|Go to my page]]"
    
    # # Creole1.0: URLs
    # tc "<p><a href=\"http://www.wikicreole.org/\">http://www.wikicreole.org/</a></p>", "[[http://www.wikicreole.org/]]"
    
    # # Creole1.0: Free-standing URL's should be turned into links
    # tc "<p><a href=\"http://www.wikicreole.org/\">http://www.wikicreole.org/</a></p>", "http://www.wikicreole.org/"
    
    # # Creole1.0: Single punctuation characters at the end of URLs
    # # should not be considered a part of the URL.
    # [',','.','?','!',':',';','\'','"'].each { |punct|
      # esc_punct = escape_html(punct)
      # tc "<p><a href=\"http://www.wikicreole.org/\">http://www.wikicreole.org/</a>#{esc_punct}</p>", "http://www.wikicreole.org/#{punct}"
    # }
    # # Creole1.0: Nameds URLs (by example)
    # tc("<p><a href=\"http://www.wikicreole.org/\">Visit the WikiCreole website</a></p>",
       # "[[http://www.wikicreole.org/|Visit the WikiCreole website]]")

    # unless $strict
      # # Parsing markup within a link is optional
      # tc "<p><a href=\"Weird+Stuff\">**Weird** //Stuff//</a></p>", "[[Weird Stuff|**Weird** //Stuff//]]"
    # end
    
    # # Inside bold
    # tc "<p><strong><a href=\"link\">link</a></strong></p>", "**[[link]]**"

    # # Whitespace inside [[ ]] should be ignored
    # tc("<p><a href=\"link\">link</a></p>", "[[ link ]]")
    # tc("<p><a href=\"link+me\">link me</a></p>", "[[ link me ]]")
    # tc("<p><a href=\"http://dot.com/\">dot.com</a></p>", "[[  http://dot.com/ \t| \t dot.com ]]")
    # tc("<p><a href=\"http://dot.com/\">dot.com</a></p>", "[[  http://dot.com/  |  dot.com ]]")
  # end
  
  # def test_larsch_paragraph
    # # Creole1.0: One or more blank lines end paragraphs.
    # tc "<p>This is my text.</p><p>This is more text.</p>", "This is\nmy text.\n\nThis is\nmore text."
    # tc "<p>This is my text.</p><p>This is more text.</p>", "This is\nmy text.\n\n\nThis is\nmore text."
    # tc "<p>This is my text.</p><p>This is more text.</p>", "This is\nmy text.\n\n\n\nThis is\nmore text."
    
    # # Creole1.0: A list end paragraphs too.
    # tc "<p>Hello</p><ul><li>Item</li></ul>", "Hello\n* Item\n"
    
    # # Creole1.0: A table end paragraphs too.
    # tc "<p>Hello</p><table><tr><td>Cell</td></tr></table>", "Hello\n|Cell|"
    
    # # Creole1.0: A nowiki end paragraphs too.
    # tc "<p>Hello</p><pre>nowiki</pre>", "Hello\n{{{\nnowiki\n}}}\n"

    # unless $strict
      # # A heading ends a paragraph (not specced)
      # tc "<p>Hello</p><h1>Heading</h1>", "Hello\n= Heading =\n"
    # end
  # end
  
  # def test_larsch_linebreak
    # # Creole1.0: \\ (wiki-style) for line breaks. 
    # tc "<p>This is the first line,<br/>and this is the second.</p>", "This is the first line,\\\\and this is the second."
  # end

  # def test_larsch_unordered_lists
    # # Creole1.0: List items begin with a * at the beginning of a line.
    # # Creole1.0: An item ends at the next *
    # tc "<ul><li>Item 1</li><li>Item 2</li><li>Item 3</li></ul>", "* Item 1\n *Item 2\n *\t\tItem 3\n"

    # # Creole1.0: Whitespace is optional before and after the *.
    # tc("<ul><li>Item 1</li><li>Item 2</li><li>Item 3</li></ul>",
       # "   *    Item 1\n*Item 2\n \t*\t\tItem 3\n")

    # # Creole1.0: A space is required if if the list element starts with bold text.
    # tc("<ul><ul><ul><li>Item 1</li></ul></ul></ul>", "***Item 1")
    # tc("<ul><li><strong>Item 1</strong></li></ul>", "* **Item 1")

    # # Creole1.0: An item ends at blank line
    # tc("<ul><li>Item</li></ul><p>Par</p>", "* Item\n\nPar\n")

    # # Creole1.0: An item ends at a heading
    # tc("<ul><li>Item</li></ul><h1>Heading</h1>", "* Item\n= Heading =\n")

    # # Creole1.0: An item ends at a table
    # tc("<ul><li>Item</li></ul><table><tr><td>Cell</td></tr></table>", "* Item\n|Cell|\n")
    
    # # Creole1.0: An item ends at a nowiki block
    # tc("<ul><li>Item</li></ul><pre>Code</pre>", "* Item\n{{{\nCode\n}}}\n")

    # # Creole1.0: An item can span multiple lines
    # tc("<ul><li>The quick brown fox jumps over lazy dog.</li><li>Humpty Dumpty sat on a wall.</li></ul>",
       # "* The quick\nbrown fox\n\tjumps over\nlazy dog.\n*Humpty Dumpty\nsat\t\non a wall.")

    # # Creole1.0: An item can contain line breaks
    # tc("<ul><li>The quick brown<br/>fox jumps over lazy dog.</li></ul>",
       # "* The quick brown\\\\fox jumps over lazy dog.")
    
    # # Creole1.0: Nested
    # tc "<ul><li>Item 1</li><ul><li>Item 2</li></ul><li>Item 3</li></ul>", "* Item 1\n **Item 2\n *\t\tItem 3\n"

    # # Creole1.0: Nested up to 5 levels
    # tc("<ul><li>Item 1</li><ul><li>Item 2</li><ul><li>Item 3</li><ul><li>Item 4</li><ul><li>Item 5</li></ul></ul></ul></ul></ul>",
       # "*Item 1\n**Item 2\n***Item 3\n****Item 4\n*****Item 5\n")

    # # Creole1.0: ** immediatly following a list element will be treated as a nested unordered element.
    # tc("<ul><li>Hello, World!</li><ul><li>Not bold</li></ul></ul>",
       # "*Hello,\nWorld!\n**Not bold\n")

    # # Creole1.0: ** immediatly following a list element will be treated as a nested unordered element.
    # tc("<ol><li>Hello, World!</li><ul><li>Not bold</li></ul></ol>",
       # "#Hello,\nWorld!\n**Not bold\n")
    
    # # Creole1.0: [...] otherwise it will be treated as the beginning of bold text.
    # tc("<ul><li>Hello, World!</li></ul><p><strong>Not bold</strong></p>",
       # "*Hello,\nWorld!\n\n**Not bold\n")
  # end

  # def test_larsch_ordered_lists
    # # Creole1.0: List items begin with a * at the beginning of a line.
    # # Creole1.0: An item ends at the next *
    # tc "<ol><li>Item 1</li><li>Item 2</li><li>Item 3</li></ol>", "# Item 1\n #Item 2\n #\t\tItem 3\n"

    # # Creole1.0: Whitespace is optional before and after the #.
    # tc("<ol><li>Item 1</li><li>Item 2</li><li>Item 3</li></ol>",
       # "   #    Item 1\n#Item 2\n \t#\t\tItem 3\n")

    # # Creole1.0: A space is required if if the list element starts with bold text.
    # tc("<ol><ol><ol><li>Item 1</li></ol></ol></ol>", "###Item 1")
    # tc("<ol><li><strong>Item 1</strong></li></ol>", "# **Item 1")

    # # Creole1.0: An item ends at blank line
    # tc("<ol><li>Item</li></ol><p>Par</p>", "# Item\n\nPar\n")

    # # Creole1.0: An item ends at a heading
    # tc("<ol><li>Item</li></ol><h1>Heading</h1>", "# Item\n= Heading =\n")

    # # Creole1.0: An item ends at a table
    # tc("<ol><li>Item</li></ol><table><tr><td>Cell</td></tr></table>", "# Item\n|Cell|\n")
    
    # # Creole1.0: An item ends at a nowiki block
    # tc("<ol><li>Item</li></ol><pre>Code</pre>", "# Item\n{{{\nCode\n}}}\n")

    # # Creole1.0: An item can span multiple lines
    # tc("<ol><li>The quick brown fox jumps over lazy dog.</li><li>Humpty Dumpty sat on a wall.</li></ol>",
       # "# The quick\nbrown fox\n\tjumps over\nlazy dog.\n#Humpty Dumpty\nsat\t\non a wall.")

    # # Creole1.0: An item can contain line breaks
    # tc("<ol><li>The quick brown<br/>fox jumps over lazy dog.</li></ol>",
       # "# The quick brown\\\\fox jumps over lazy dog.")
    
    # # Creole1.0: Nested
    # tc "<ol><li>Item 1</li><ol><li>Item 2</li></ol><li>Item 3</li></ol>", "# Item 1\n ##Item 2\n #\t\tItem 3\n"

    # # Creole1.0: Nested up to 5 levels
    # tc("<ol><li>Item 1</li><ol><li>Item 2</li><ol><li>Item 3</li><ol><li>Item 4</li><ol><li>Item 5</li></ol></ol></ol></ol></ol>",
       # "#Item 1\n##Item 2\n###Item 3\n####Item 4\n#####Item 5\n")

    # # Creole1.0_Infered: The two-bullet rule only applies to **.
    # tc("<ol><ol><li>Item</li></ol></ol>", "##Item")
  # end
  
  # def test_larsch_ordered_lists2
    # tc "<ol><li>Item 1</li><li>Item 2</li><li>Item 3</li></ol>", "# Item 1\n #Item 2\n #\t\tItem 3\n"
    # # Nested
    # tc "<ol><li>Item 1</li><ol><li>Item 2</li></ol><li>Item 3</li></ol>", "# Item 1\n ##Item 2\n #\t\tItem 3\n"
    # # Multiline
    # tc "<ol><li>Item 1 on multiple lines</li></ol>", "# Item 1\non multiple lines"
  # end

  # def test_larsch_ambiguity_mixed_lists
    # # ol following ul
    # tc("<ul><li>uitem</li></ul><ol><li>oitem</li></ol>", "*uitem\n#oitem\n")
    
    # # ul following ol
    # tc("<ol><li>uitem</li></ol><ul><li>oitem</li></ul>", "#uitem\n*oitem\n")
    
    # # 2ol following ul
    # tc("<ul><li>uitem</li><ol><li>oitem</li></ol></ul>", "*uitem\n##oitem\n")
    
    # # 2ul following ol
    # tc("<ol><li>uitem</li><ul><li>oitem</li></ul></ol>", "#uitem\n**oitem\n")
    
    # # 3ol following 3ul
    # tc("<ul><ul><ul><li>uitem</li></ul><ol><li>oitem</li></ol></ul></ul>", "***uitem\n###oitem\n")
    
    # # 2ul following 2ol
    # tc("<ol><ol><li>uitem</li></ol><ul><li>oitem</li></ul></ol>", "##uitem\n**oitem\n")
    
    # # ol following 2ol
    # tc("<ol><ol><li>oitem1</li></ol><li>oitem2</li></ol>", "##oitem1\n#oitem2\n")
    # # ul following 2ol
    # tc("<ol><ol><li>oitem1</li></ol></ol><ul><li>oitem2</li></ul>", "##oitem1\n*oitem2\n")
  # end

  # def test_larsch_ambiguity_italics_and_url
    # # Uncommon URL schemes should not be parsed as URLs
    # tc("<p>This is what can go wrong:<em>this should be an italic text</em>.</p>",
       # "This is what can go wrong://this should be an italic text//.")

    # # A link inside italic text
    # tc("<p>How about <em>a link, like <a href=\"http://example.org\">http://example.org</a>, in italic</em> text?</p>",
       # "How about //a link, like http://example.org, in italic// text?")

    # # Another test from Creole Wiki
    # tc("<p>Formatted fruits, for example:<em>apples</em>, oranges, <strong>pears</strong> ...</p>",
       # "Formatted fruits, for example://apples//, oranges, **pears** ...")
  # end

  # def test_ambiguity_bold_and_lists
    # tc "<p><strong> bold text </strong></p>", "** bold text **"
    # tc "<p> <strong> bold text </strong></p>", " ** bold text **"
  # end

  # def test_larsch_nowiki
    # # ... works as block
    # tc "<pre>Hello</pre>", "{{{\nHello\n}}}\n"

    # # ... works inline
    # tc "<p>Hello <tt>world</tt>.</p>", "Hello {{{world}}}."
    
    # # Creole1.0: No wiki markup is interpreted inbetween
    # tc "<pre>**Hello**</pre>", "{{{\n**Hello**\n}}}\n"

    # # Creole1.0: Leading whitespaces are not permitted
    # tc("<p> {{{ Hello }}}</p>", " {{{\nHello\n}}}")
    # tc("<p>{{{ Hello }}}</p>", "{{{\nHello\n }}}")
    
    # # Assumed: Should preserve whitespace
    # tc("<pre> \t Hello, \t \n \t World \t </pre>",
       # "{{{\n \t Hello, \t \n \t World \t \n}}}\n")

    # # In preformatted blocks ... one leading space is removed
    # tc("<pre>nowikiblock\n}}}</pre>", "{{{\nnowikiblock\n }}}\n}}}\n")

    # # In inline nowiki, any trailing closing brace is included in the span
    # tc("<p>this is <tt>nowiki}</tt></p>", "this is {{{nowiki}}}}")
    # tc("<p>this is <tt>nowiki}}</tt></p>", "this is {{{nowiki}}}}}")
    # tc("<p>this is <tt>nowiki}}}</tt></p>", "this is {{{nowiki}}}}}}")
    # tc("<p>this is <tt>nowiki}}}}</tt></p>", "this is {{{nowiki}}}}}}}")
  # end

  # def test_larsch_html_escaping
    # # Special HTML chars should be escaped
    # tc("<p>&lt;b&gt;not bold&lt;/b&gt;</p>", "<b>not bold</b>")

    # # Image tags should be escape
    # tc("<p><img src=\"image.jpg\" alt=\"&quot;tag&quot;\"/></p>", "{{image.jpg|\"tag\"}}")

    # # Malicious links should not be converted.
    # tc("<p><a href=\"javascript%3Aalert%28%22Boo%21%22%29\">Click</a></p>", "[[javascript:alert(\"Boo!\")|Click]]")
  # end

  # def test_larschescape
    # tc "<p>** Not Bold **</p>", "~** Not Bold ~**"
    # tc "<p>// Not Italic //</p>", "~// Not Italic ~//"
    # tc "<p>* Not Bullet</p>", "~* Not Bullet"
    # # Following char is not a blank (space or line feed)
    # tc "<p>Hello ~ world</p>", "Hello ~ world\n"
    # tc "<p>Hello ~ world</p>", "Hello ~\nworld\n"
    # # Not escaping inside URLs (Creole1.0 not clear on this)
    # tc "<p><a href=\"http://example.org/~user/\">http://example.org/~user/</a></p>", "http://example.org/~user/"
    
    # # Escaping links
    # tc "<p>http://www.wikicreole.org/</p>", "~http://www.wikicreole.org/"
  # end

  # def test_larsch_horizontal_rule
    # # Creole: Four hyphens make a horizontal rule
    # tc "<hr/>", "----"

    # # Creole1.0: Whitespace around them is allowed
    # tc "<hr/>", " ----"
    # tc "<hr/>", "----  "
    # tc "<hr/>", "  ----  "
    # tc "<hr/>", " \t ---- \t "

    # # Creole1.0: Nothing else than hyphens and whitespace is "allowed"
    # tc "<p>foo ----</p>", "foo ----\n"
    # tc "<p>---- foo</p>", "---- foo\n"

    # # Creole1.0: [...] no whitespace is allowed between them
    # tc "<p> -- -- </p>", "  -- --  "
    # tc "<p> -- -- </p>", "  --\t--  "
  # end

  # def test_larsch_table
    # tc "<table><tr><td>Hello, World!</td></tr></table>", "|Hello, World!|"
    # # Multiple columns
    # tc "<table><tr><td>c1</td><td>c2</td><td>c3</td></tr></table>", "|c1|c2|c3|"
    # # Multiple rows
    # tc "<table><tr><td>c11</td><td>c12</td></tr><tr><td>c21</td><td>c22</td></tr></table>", "|c11|c12|\n|c21|c22|\n"
    # # End pipe is optional
    # tc "<table><tr><td>c1</td><td>c2</td><td>c3</td></tr></table>", "|c1|c2|c3"
    # # Empty cells
    # tc "<table><tr><td>c1</td><td></td><td>c3</td></tr></table>", "|c1||c3"
    # # Escaping cell separator
    # tc "<table><tr><td>c1|c2</td><td>c3</td></tr></table>", "|c1~|c2|c3"
    # # Escape in last cell + empty cell
    # tc "<table><tr><td>c1</td><td>c2|</td></tr></table>", "|c1|c2~|"
    # tc "<table><tr><td>c1</td><td>c2|</td></tr></table>", "|c1|c2~||"
    # tc "<table><tr><td>c1</td><td>c2|</td><td></td></tr></table>", "|c1|c2~|||"
    # # Equal sign after pipe make a header
    # tc "<table><tr><th>Header</th></tr></table>", "|=Header|"
  # end

  # def test_larsch_following_table
    # # table followed by heading
    # tc("<table><tr><td>table</td></tr></table><h1>heading</h1>", "|table|\n=heading=\n")
    # tc("<table><tr><td>table</td></tr></table><h1>heading</h1>", "|table|\n\n=heading=\n")
    # # table followed by paragraph
    # tc("<table><tr><td>table</td></tr></table><p>par</p>", "|table|\npar\n")
    # tc("<table><tr><td>table</td></tr></table><p>par</p>", "|table|\n\npar\n")
    # # table followed by unordered list
    # tc("<table><tr><td>table</td></tr></table><ul><li>item</li></ul>", "|table|\n*item\n")
    # tc("<table><tr><td>table</td></tr></table><ul><li>item</li></ul>", "|table|\n\n*item\n")
    # # table followed by ordered list
    # tc("<table><tr><td>table</td></tr></table><ol><li>item</li></ol>", "|table|\n#item\n")
    # tc("<table><tr><td>table</td></tr></table><ol><li>item</li></ol>", "|table|\n\n#item\n")
    # # table followed by horizontal rule
    # tc("<table><tr><td>table</td></tr></table><hr/>", "|table|\n----\n")
    # tc("<table><tr><td>table</td></tr></table><hr/>", "|table|\n\n----\n")
    # # table followed by nowiki block
    # tc("<table><tr><td>table</td></tr></table><pre>pre</pre>", "|table|\n{{{\npre\n}}}\n")
    # tc("<table><tr><td>table</td></tr></table><pre>pre</pre>", "|table|\n\n{{{\npre\n}}}\n")
    # # table followed by table
    # tc("<table><tr><td>table</td></tr><tr><td>table</td></tr></table>", "|table|\n|table|\n")
    # tc("<table><tr><td>table</td></tr></table><table><tr><td>table</td></tr></table>", "|table|\n\n|table|\n")
  # end

  # def test_larsch_following_heading
    # # heading
    # tc("<h1>heading1</h1><h1>heading2</h1>", "=heading1=\n=heading2\n")
    # tc("<h1>heading1</h1><h1>heading2</h1>", "=heading1=\n\n=heading2\n")
    # # paragraph
    # tc("<h1>heading</h1><p>par</p>", "=heading=\npar\n")
    # tc("<h1>heading</h1><p>par</p>", "=heading=\n\npar\n")
    # # unordered list
    # tc("<h1>heading</h1><ul><li>item</li></ul>", "=heading=\n*item\n")
    # tc("<h1>heading</h1><ul><li>item</li></ul>", "=heading=\n\n*item\n")
    # # ordered list
    # tc("<h1>heading</h1><ol><li>item</li></ol>", "=heading=\n#item\n")
    # tc("<h1>heading</h1><ol><li>item</li></ol>", "=heading=\n\n#item\n")
    # # horizontal rule
    # tc("<h1>heading</h1><hr/>", "=heading=\n----\n")
    # tc("<h1>heading</h1><hr/>", "=heading=\n\n----\n")
    # # nowiki block
    # tc("<h1>heading</h1><pre>nowiki</pre>", "=heading=\n{{{\nnowiki\n}}}\n")
    # tc("<h1>heading</h1><pre>nowiki</pre>", "=heading=\n\n{{{\nnowiki\n}}}\n")
    # # table
    # tc("<h1>heading</h1><table><tr><td>table</td></tr></table>", "=heading=\n|table|\n")
    # tc("<h1>heading</h1><table><tr><td>table</td></tr></table>", "=heading=\n\n|table|\n")
  # end

  # def test_larsch_following_paragraph
    # # heading
    # tc("<p>par</p><h1>heading</h1>", "par\n=heading=")
    # tc("<p>par</p><h1>heading</h1>", "par\n\n=heading=")
    # # paragraph
    # tc("<p>par par</p>", "par\npar\n")
    # tc("<p>par</p><p>par</p>", "par\n\npar\n")
    # # unordered
    # tc("<p>par</p><ul><li>item</li></ul>", "par\n*item")
    # tc("<p>par</p><ul><li>item</li></ul>", "par\n\n*item")
    # # ordered
    # tc("<p>par</p><ol><li>item</li></ol>", "par\n#item\n")
    # tc("<p>par</p><ol><li>item</li></ol>", "par\n\n#item\n")
    # # horizontal
    # tc("<p>par</p><hr/>", "par\n----\n")
    # tc("<p>par</p><hr/>", "par\n\n----\n")
    # # nowiki
    # tc("<p>par</p><pre>nowiki</pre>", "par\n{{{\nnowiki\n}}}\n")
    # tc("<p>par</p><pre>nowiki</pre>", "par\n\n{{{\nnowiki\n}}}\n")
    # # table
    # tc("<p>par</p><table><tr><td>table</td></tr></table>", "par\n|table|\n")
    # tc("<p>par</p><table><tr><td>table</td></tr></table>", "par\n\n|table|\n")
  # end
  
  # def test_larsch_following_unordered_list
    # # heading
    # tc("<ul><li>item</li></ul><h1>heading</h1>", "*item\n=heading=")
    # tc("<ul><li>item</li></ul><h1>heading</h1>", "*item\n\n=heading=")
    # # paragraph
    # tc("<ul><li>item par</li></ul>", "*item\npar\n") # items may span multiple lines
    # tc("<ul><li>item</li></ul><p>par</p>", "*item\n\npar\n")
    # # unordered
    # tc("<ul><li>item</li><li>item</li></ul>", "*item\n*item\n")
    # tc("<ul><li>item</li></ul><ul><li>item</li></ul>", "*item\n\n*item\n")
    # # ordered
    # tc("<ul><li>item</li></ul><ol><li>item</li></ol>", "*item\n#item\n")
    # tc("<ul><li>item</li></ul><ol><li>item</li></ol>", "*item\n\n#item\n")
    # # horizontal rule
    # tc("<ul><li>item</li></ul><hr/>", "*item\n----\n")
    # tc("<ul><li>item</li></ul><hr/>", "*item\n\n----\n")
    # # nowiki
    # tc("<ul><li>item</li></ul><pre>nowiki</pre>", "*item\n{{{\nnowiki\n}}}\n")
    # tc("<ul><li>item</li></ul><pre>nowiki</pre>", "*item\n\n{{{\nnowiki\n}}}\n")
    # # table
    # tc("<ul><li>item</li></ul><table><tr><td>table</td></tr></table>", "*item\n|table|\n")
    # tc("<ul><li>item</li></ul><table><tr><td>table</td></tr></table>", "*item\n\n|table|\n")
  # end

  # def test_larsch_following_ordered_list
    # # heading
    # tc("<ol><li>item</li></ol><h1>heading</h1>", "#item\n=heading=")
    # tc("<ol><li>item</li></ol><h1>heading</h1>", "#item\n\n=heading=")
    # # paragraph
    # tc("<ol><li>item par</li></ol>", "#item\npar\n") # items may span multiple lines
    # tc("<ol><li>item</li></ol><p>par</p>", "#item\n\npar\n")
    # # unordered
    # tc("<ol><li>item</li></ol><ul><li>item</li></ul>", "#item\n*item\n")
    # tc("<ol><li>item</li></ol><ul><li>item</li></ul>", "#item\n\n*item\n")
    # # ordered
    # tc("<ol><li>item</li><li>item</li></ol>", "#item\n#item\n")
    # tc("<ol><li>item</li></ol><ol><li>item</li></ol>", "#item\n\n#item\n")
    # # horizontal role
    # tc("<ol><li>item</li></ol><hr/>", "#item\n----\n")
    # tc("<ol><li>item</li></ol><hr/>", "#item\n\n----\n")
    # # nowiki
    # tc("<ol><li>item</li></ol><pre>nowiki</pre>", "#item\n{{{\nnowiki\n}}}\n")
    # tc("<ol><li>item</li></ol><pre>nowiki</pre>", "#item\n\n{{{\nnowiki\n}}}\n")
    # # table
    # tc("<ol><li>item</li></ol><table><tr><td>table</td></tr></table>", "#item\n|table|\n")
    # tc("<ol><li>item</li></ol><table><tr><td>table</td></tr></table>", "#item\n\n|table|\n")
  # end

  # def test_larsch_following_horizontal_rule
    # # heading
    # tc("<hr/><h1>heading</h1>", "----\n=heading=")
    # tc("<hr/><h1>heading</h1>", "----\n\n=heading=")
    # # paragraph
    # tc("<hr/><p>par</p>", "----\npar\n")
    # tc("<hr/><p>par</p>", "----\n\npar\n")
    # # unordered
    # tc("<hr/><ul><li>item</li></ul>", "----\n*item")
    # tc("<hr/><ul><li>item</li></ul>", "----\n*item")
    # # ordered
    # tc("<hr/><ol><li>item</li></ol>", "----\n#item")
    # tc("<hr/><ol><li>item</li></ol>", "----\n#item")
    # # horizontal
    # tc("<hr/><hr/>", "----\n----\n")
    # tc("<hr/><hr/>", "----\n\n----\n")
    # # nowiki
    # tc("<hr/><pre>nowiki</pre>", "----\n{{{\nnowiki\n}}}\n")
    # tc("<hr/><pre>nowiki</pre>", "----\n\n{{{\nnowiki\n}}}\n")
    # # table
    # tc("<hr/><table><tr><td>table</td></tr></table>", "----\n|table|\n")
    # tc("<hr/><table><tr><td>table</td></tr></table>", "----\n\n|table|\n")
  # end

  # def test_larsch_following_nowiki_block
    # # heading
    # tc("<pre>nowiki</pre><h1>heading</h1>", "{{{\nnowiki\n}}}\n=heading=")
    # tc("<pre>nowiki</pre><h1>heading</h1>", "{{{\nnowiki\n}}}\n\n=heading=")
    # # paragraph
    # tc("<pre>nowiki</pre><p>par</p>", "{{{\nnowiki\n}}}\npar")
    # tc("<pre>nowiki</pre><p>par</p>", "{{{\nnowiki\n}}}\n\npar")
    # # unordered
    # tc("<pre>nowiki</pre><ul><li>item</li></ul>", "{{{\nnowiki\n}}}\n*item\n")
    # tc("<pre>nowiki</pre><ul><li>item</li></ul>", "{{{\nnowiki\n}}}\n\n*item\n")
    # # ordered
    # tc("<pre>nowiki</pre><ol><li>item</li></ol>", "{{{\nnowiki\n}}}\n#item\n")
    # tc("<pre>nowiki</pre><ol><li>item</li></ol>", "{{{\nnowiki\n}}}\n\n#item\n")
    # # horizontal
    # tc("<pre>nowiki</pre><hr/>", "{{{\nnowiki\n}}}\n----\n")
    # tc("<pre>nowiki</pre><hr/>", "{{{\nnowiki\n}}}\n\n----\n")
    # # nowiki
    # tc("<pre>nowiki</pre><pre>nowiki</pre>", "{{{\nnowiki\n}}}\n{{{\nnowiki\n}}}\n")
    # tc("<pre>nowiki</pre><pre>nowiki</pre>", "{{{\nnowiki\n}}}\n\n{{{\nnowiki\n}}}\n")
    # # table
    # tc("<pre>nowiki</pre><table><tr><td>table</td></tr></table>", "{{{\nnowiki\n}}}\n|table|\n")
    # tc("<pre>nowiki</pre><table><tr><td>table</td></tr></table>", "{{{\nnowiki\n}}}\n\n|table|\n")
  # end

  # def test_larsch_image
    # tc("<p><img src=\"image.jpg\"/></p>", "{{image.jpg}}")
    # tc("<p><img src=\"image.jpg\" alt=\"tag\"/></p>", "{{image.jpg|tag}}")
    # tc("<p><img src=\"http://example.org/image.jpg\"/></p>", "{{http://example.org/image.jpg}}")
  # end

  # def test_larsch_bold_combo
    # tc("<p><strong>bold and</strong></p><table><tr><td>table</td></tr></table><p>end<strong></strong></p>",
       # "**bold and\n|table|\nend**")
  # end
  
  def tc(html, creole)
    output = WikiCreole.creole_parse(creole)
    
    #if it's one of the specially formatted blocks of html, then strip it
    if html.index(/\n {4}$/m)
      html.sub!(/^\n/, "")
      html.gsub!(/^ {4}/, "")
    end
    
    assert_equal html, output
  end

end
