local luaunit = require("luaunit")
local xmlua = require("xmlua")

local ffi = require("ffi")

TestXMLSAXParser = {}

function TestXMLSAXParser.test_start_document()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
]]
  local parser = xmlua.XMLSAXParser.new()
  local called = false
  parser.start_document = function()
    called = true
  end

  local succeeded = parser:parse(xml)
  luaunit.assertEquals({succeeded, called}, {true, true})
end

local function collect_parameter_entities(chunk)
  local parser = xmlua.XMLSAXParser.new()
  local parameter_entities = {}
  parser.get_parameter_entity = function(name)
    local parameter_entity = {
      name = name,
    }
    table.insert(parameter_entities, parameter_entity)
  end
  luaunit.assertEquals(parser:parse(chunk), true)
  return parameter_entities
end

function TestXMLSAXParser.test_get_parameter_entity()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE EXAMPLE[
<!ENTITY % Sample "This is Sample">
]>
]]
  local expected = {
                     {name = "Sample"},
                   }
  luaunit.assertEquals(collect_parameter_entities(xml), expected)
end

local function collect_unparsed_entity_declarations(chunk)
  local parser = xmlua.XMLSAXParser.new()
  local unparsed_entities = {}
  parser.unparsed_entity_declaration = function(name,
                                                public_id,
                                                system_id,
                                                notation_name)
    local unparsed_entity = {
      name = name,
      public_id = public_id,
      system_id = system_id,
      notation_name = notation_name
    }
    table.insert(unparsed_entities, unparsed_entity)
  end
  luaunit.assertEquals(parser:parse(chunk), true)
  return unparsed_entities
end

function TestXMLSAXParser.test_unparsed_entity_declaration_with_system_id()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE example [
  <!ELEMENT example EMPTY>
  <!ENTITY test SYSTEM "file:///usr/local/share/test.gif" NDATA gif>
]>
]]
  local expected = {
                     {
                       name = "test",
                       public_id = nil,
                       system_id = "file:///usr/local/share/test.gif",
                       notation_name = "gif",
                     }
                   }
  luaunit.assertEquals(collect_unparsed_entity_declarations(xml),
                       expected)
end

function TestXMLSAXParser.test_unparsed_entity_declaration_with_public_id()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE example [
  <!ELEMENT example EMPTY>
  <!ENTITY test PUBLIC "-//test//test test//EN"
   "http://www.test.org/test.gif" NDATA gif>
]>
]]
  local expected = {
                     {
                       name = "test",
                       public_id = "-//test//test test//EN",
                       system_id = "http://www.test.org/test.gif",
                       notation_name = "gif",
                     }
                   }
  luaunit.assertEquals(collect_unparsed_entity_declarations(xml),
                       expected)
end

local function collect_notation_declarations(chunk)
  local parser = xmlua.XMLSAXParser.new()
  local notations = {}
  parser.notation_declaration = function(name,
                                         public_id,
                                         system_id)
    local notation = {
      name = name,
      public_id = public_id,
      system_id = system_id,
    }
    table.insert(notations, notation)
  end
  luaunit.assertEquals(parser:parse(chunk), true)
  return notations
end

function TestXMLSAXParser.test_notation_declaration_with_system_id()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE example [
  <!ELEMENT example EMPTY>
  <!NOTATION test SYSTEM "Test">
]>
]]
  local expected = {
                     {
                       name = "test",
                       public_id = nil,
                       system_id = "Test",
                     }
                   }
  luaunit.assertEquals(collect_notation_declarations(xml), expected)
end

function TestXMLSAXParser.test_notation_declaration_with_public_id()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE example [
  <!ELEMENT example EMPTY>
  <!NOTATION test PUBLIC "Test">
]>
]]
  local expected = {
                     {
                       name = "test",
                       public_id = "Test",
                       system_id = nil,
                     }
                   }
  luaunit.assertEquals(collect_notation_declarations(xml), expected)
end

local function collect_entity_declarations(chunk)
  local parser = xmlua.XMLSAXParser.new()
  local entities = {}
  parser.entity_declaration = function(name,
                                       entity_type,
                                       public_id,
                                       system_id,
                                       content)
    local entity = {
      name = name,
      entity_type = entity_type,
      public_id = public_id,
      system_id = system_id,
      content = content
    }
    table.insert(entities, entity)
  end
  luaunit.assertEquals(parser:parse(chunk), true)
  return entities
end

function TestXMLSAXParser.test_entity_declaration_with_external_entity()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE root SYSTEM "file:///usr/local/share/test.dtd" [
<!ENTITY test "This is test.">
]>
<root>
	<data>&test;</data>
</root>
]]
  local expected = {
                     {
                       name = "test",
                       entity_type = 1,
                       public_id = nil,
                       system_id = nil,
                       content = "This is test."
                     }
                   }
  luaunit.assertEquals(collect_entity_declarations(xml), expected)
end

local function collect_get_entities(chunk)
  local parser = xmlua.XMLSAXParser.new()
  local entities = {}
  parser.get_entity = function(name)
    local entity = {
      name = name,
    }
    table.insert(entities, entity)
  end
  luaunit.assertEquals(parser:parse(chunk), true)
  return entities
end

function TestXMLSAXParser.test_get_entity_with_internal_entity()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE EXAMPLE[
<!ELEMENT EXAMPLE (TEST)>
<!ELEMENT TEST EMPTY>
<!ENTITY Sample "This is Sample">
]>

<EXAMPLE>
&Sample;
</EXAMPLE>
]]
  local expected = {
                     {name = "Sample"},
                     {name = "Sample"}
                   }
  luaunit.assertEquals(collect_get_entities(xml), expected)
end

function TestXMLSAXParser.test_get_entity_with_external_entity()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE EXAMPLE[
<!ELEMENT EXAMPLE (TEST)>
<!ELEMENT TEST EMPTY>
<!ENTITY Sample1 SYSTEM "file:///usr/local/share/test.dtd">
<!ENTITY Sample2 PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtdSYSTEM">
]>

<EXAMPLE>
&Sample1;
&Sample2;
</EXAMPLE>
]]
  local expected = {
                     {name = "Sample1"},
                     {name = "Sample2"}
                   }
  luaunit.assertEquals(collect_get_entities(xml), expected)
end

local function collect_internal_subsets(chunk)
  local parser = xmlua.XMLSAXParser.new()
  local internal_subsets = {}
  parser.internal_subset = function(name,
                                    external_id,
                                    system_id)
    local internal_subset = {
      name = name,
      external_id = external_id,
      system_id = system_id,
    }
    table.insert(internal_subsets, internal_subset)
  end
  luaunit.assertEquals(parser:parse(chunk), true)
  return internal_subsets
end

function TestXMLSAXParser.test_internal_subset()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE EXAMPLE[
<!ELEMENT EXAMPLE (TEST1, TEST2)>
<!ELEMENT TEST1 EMPTY>
<!ELEMENT TEST2 EMPTY>
]>
]]
  local expected = {
                     {name = "EXAMPLE"}
                   }
  luaunit.assertEquals(collect_internal_subsets(xml), expected)
end

function TestXMLSAXParser.test_internal_subset_with_systemid()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE EXAMPLE SYSTEM "file:///usr/local/share/test.dtd"[
<!ELEMENT EXAMPLE (TEST1, TEST2)>
<!ELEMENT TEST1 EMPTY>
<!ELEMENT TEST2 EMPTY>
]>
]]
  local expected = {
                     {
                       name = "EXAMPLE",
                       external_id = nil,
                       system_id = "file:///usr/local/share/test.dtd"
                     }
                   }
  luaunit.assertEquals(collect_internal_subsets(xml), expected)
end

function TestXMLSAXParser.test_internal_subset_with_externalid()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE EXAMPLE PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"[
<!ELEMENT EXAMPLE (TEST1, TEST2)>
<!ELEMENT TEST1 EMPTY>
<!ELEMENT TEST2 EMPTY>
]>
]]
  local expected = {
                     {
                       name = "EXAMPLE",
                       external_id = "-//W3C//DTD XHTML 1.0 Transitional//EN",
                       system_id =
                         "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
                     }
                   }
  luaunit.assertEquals(collect_internal_subsets(xml), expected)
end

local function collect_external_subsets(chunk)
  local parser = xmlua.XMLSAXParser.new()
  local external_subsets = {}
  parser.external_subset = function(name,
                                    external_id,
                                    system_id)
    local external_subset = {
      name = name,
      external_id = external_id,
      system_id = system_id,
    }
    table.insert(external_subsets, external_subset)
  end
  luaunit.assertEquals(parser:parse(chunk), true)
  return external_subsets
end

function TestXMLSAXParser.test_external_subset()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
]]
  local expected = {
    {
      name = "html",
      external_id = "-//W3C//DTD XHTML 1.0 Transitional//EN",
      system_id = "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd",
    },
  }
  luaunit.assertEquals(collect_external_subsets(xml), expected)
end

function TestXMLSAXParser.test_cdata_block()
  local xml = [=[
<?xml version="1.0" encoding="UTF-8" ?>
<xml>
<![CDATA[<p>Hello world!</p>]]>
</xml>
]=]
  local parser = xmlua.XMLSAXParser.new()
  local cdata_blocks = {}
  parser.cdata_block = function(cdata_block)
    table.insert(cdata_blocks, cdata_block)
  end
  local succeeded = parser:parse(xml)
  luaunit.assertEquals({succeeded, cdata_blocks},
                       {true, {"<p>Hello world!</p>"}})
end


function TestXMLSAXParser.test_comment()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<xml><!--This is comment--></xml>
]]
  local parser = xmlua.XMLSAXParser.new()
  local comments = {}
  parser.comment = function(comment)
    table.insert(comments, comment)
  end
  local succeeded = parser:parse(xml)
  luaunit.assertEquals({succeeded, comments},
                       {true, {"This is comment"}})
end


function TestXMLSAXParser.test_processing_instruction()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<?xml-stylesheet href="www.test.com/test-style.xsl" type="text/xsl" ?>
]]
  local parser = xmlua.XMLSAXParser.new()
  local targets = {}
  local data_list = {}
  parser.processing_instruction = function(target, data)
    table.insert(targets, target)
    table.insert(data_list, data)
  end
  local succeeded = parser:parse(xml)
  luaunit.assertEquals({succeeded, targets, data_list},
                       {true,
                       {"xml-stylesheet"},
                       {"href=\"www.test.com/test-style.xsl\" type=\"text/xsl\" "}})
end


function TestXMLSAXParser.test_ignorable_whitespace()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<xml>
  <test></test>
</xml>
]]
  local parser = xmlua.XMLSAXParser.new()
  local ignorable_whitespaces_list = {}

  parser.ignorable_whitespace = function(ignorable_whitespaces)
    table.insert(ignorable_whitespaces_list, ignorable_whitespaces)
  end
  local succeeded = parser:parse(xml)
  luaunit.assertEquals({succeeded, ignorable_whitespaces_list},
                       {true, {"\n  ", "\n"}})
end


local function collect_texts(chunk)
  local parser = xmlua.XMLSAXParser.new()
  local texts = {}
  parser.text = function(text)
    table.insert(texts, text)
  end
  luaunit.assertEquals(parser:parse(chunk), true)
  return texts
end

function TestXMLSAXParser.test_text()
  local xml = [[
<?xml version="1.0" encoding="UTF-8"?>
<book>
  <title>Hello World</title>
</book>
]]
  local expected = {
    "Hello World",
    "\n",
  }
  luaunit.assertEquals(collect_texts(xml), expected)
end


function TestXMLSAXParser.test_reference()
  local xml = [[
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE test [
  <!ENTITY ref "Reference">
]>
<test>&ref;</test>
]]
  local parser = xmlua.XMLSAXParser.new()
  local entity_names = {}
  parser.reference = function(entity_name)
    table.insert(entity_names, entity_name)
  end

  local succeeded = parser:parse(xml)
  luaunit.assertEquals({succeeded, entity_names}, {true, {"ref"}})
end


local function collect_start_elements(chunk)
  local parser = xmlua.XMLSAXParser.new()
  local elements = {}
  parser.start_element = function(local_name,
                                  prefix,
                                  uri,
                                  namespaces,
                                  attributes)
    local element = {
      local_name = local_name,
      prefix = prefix,
      uri = uri,
      namespaces = namespaces,
      name = name,
      attributes = attributes,
    }
    table.insert(elements, element)
  end
  luaunit.assertEquals(parser:parse(chunk), true)
  return elements
end


function TestXMLSAXParser.test_start_element_no_namespace()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<xml>
]]
  local expected = {
    {
      local_name = "xml",
      namespaces = {},
      attributes = {},
    },
  }
  luaunit.assertEquals(collect_start_elements(xml), expected)
end

function TestXMLSAXParser.test_start_element_attributes_no_namespace()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<product id="20180101" name="xmlua">
]]
  local expected = {
    {
      local_name = "product",
      namespaces = {},
      attributes = {
        {
          local_name = "id",
          value = "20180101",
          is_default = false,
        },
        {
          local_name = "name",
          value = "xmlua",
          is_default = false,
        },
      },
    },
  }
  luaunit.assertEquals(collect_start_elements(xml),
                       expected)
end

function TestXMLSAXParser.test_start_element_with_namespace()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<xhtml:html xmlns:xhtml="http://www.w3.org/1999/xhtml"
  id="top"
  xhtml:class="top-level">
]]
  local expected = {
    {
      local_name = "html",
      prefix = "xhtml",
      uri = "http://www.w3.org/1999/xhtml",
      namespaces = {
        xhtml = "http://www.w3.org/1999/xhtml",
      },
      attributes = {
        {
          local_name = "id",
          value = "top",
          is_default = false,
        },
        {
          local_name = "class",
          prefix = "xhtml",
          uri = "http://www.w3.org/1999/xhtml",
          value = "top-level",
          is_default = false,
        },
      },
    },
  }
  luaunit.assertEquals(collect_start_elements(xml),
                       expected)
end

function TestXMLSAXParser.test_start_element_with_default_namespace()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<html xmlns="http://www.w3.org/1999/xhtml"
  id="top"
  class="top-level">
]]
  local expected = {
    {
      local_name = "html",
      uri = "http://www.w3.org/1999/xhtml",
      namespaces = {},
      attributes = {
        {
          local_name = "id",
          value = "top",
          is_default = false,
        },
        {
          local_name = "class",
          value = "top-level",
          is_default = false,
        },
      },
    },
  }
  expected[1].namespaces[""] = "http://www.w3.org/1999/xhtml"
  luaunit.assertEquals(collect_start_elements(xml),
                       expected)
end


local function collect_end_elements(chunk)
  local parser = xmlua.XMLSAXParser.new()
  local elements = {}
  parser.end_element = function(local_name,
                                prefix,
                                uri)
    local element = {
      local_name = local_name,
      prefix = prefix,
      uri = uri,
    }
    table.insert(elements, element)
  end
  luaunit.assertEquals(parser:parse(chunk), true)
  return elements
end

function TestXMLSAXParser.test_end_element_no_namespace()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<xml></xml>
]]

  local expected = {
    {
      local_name = "xml",
    },
  }
  luaunit.assertEquals(collect_end_elements(xml), expected)
end

function TestXMLSAXParser.test_end_element_with_namespace()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<xhtml:html xmlns:xhtml="http://www.w3.org/1999/xhtml">
</xhtml:html>
]]

  local expected = {
    {
      local_name = "html",
      prefix = "xhtml",
      uri = "http://www.w3.org/1999/xhtml",
    },
  }
  luaunit.assertEquals(collect_end_elements(xml),
                       expected)
end

function TestXMLSAXParser.test_end_element_with_default_namespace()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<html xmlns="http://www.w3.org/1999/xhtml">
</html>
]]
  local expected = {
    {
      local_name = "html",
      uri = "http://www.w3.org/1999/xhtml",
    },
  }
  luaunit.assertEquals(collect_end_elements(xml),
                       expected)
end

local function collect_warnings(chunk)
  local parser = xmlua.XMLSAXParser.new()
  local xml_warnings = {}
  parser.warning = function(message)
    table.insert(xml_warnings, message)
  end
  luaunit.assertEquals(parser:parse(chunk), true)
  return xml_warnings
end

function TestXMLSAXParser.test_warning()
  local xml = [[
<?xml version="1.0"?>
<?xmlo ?>
]]
  local expected = {
                     "xmlParsePITarget: invalid name prefix 'xml'\n"
                   }
  luaunit.assertEquals(collect_warnings(xml), expected)
end

function TestXMLSAXParser.test_set_pedantic_as_option()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE root SYSTEM "file:///usr/local/share/test.dtd" [
<!ENTITY test "This is test.">
<!ENTITY test "This is test.">
]>
<root>
       <data>&test;</data>
</root>
]]
  local options = {pedantic = true}
  local parser = xmlua.XMLSAXParser.new(options)

  local warnings = {}
  parser.warning = function(message)
    table.insert(warnings, message)
  end
  local succeeded = parser:parse(xml)
  luaunit.assertEquals({succeeded, warnings},
                       {
                        true,
                        {"Entity(test) already defined in the internal subset\n"}
                       })
end

function TestXMLSAXParser.test_set_pedantic()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE root SYSTEM "file:///usr/local/share/test.dtd" [
<!ENTITY test "This is test.">
<!ENTITY test "This is test.">
]>
<root>
       <data>&test;</data>
</root>
]]
  local parser = xmlua.XMLSAXParser.new()
  parser.pedantic = true

  local warnings = {}
  parser.warning = function(message)
    table.insert(warnings, message)
  end
  local succeeded = parser:parse(xml)
  luaunit.assertEquals({succeeded, warnings},
                       {
                        true,
                        {"Entity(test) already defined in the internal subset\n"}
                       })
end

function TestXMLSAXParser.test_get_pedantic()
  local parser = xmlua.XMLSAXParser.new()
  parser.pedantic = true
  luaunit.assertEquals(parser.pedantic, true)
end

local function collect_xml_errors(chunk)
  local parser = xmlua.XMLSAXParser.new()
  local xml_errors = {}
  parser.error = function(xml_error)
    table.insert(xml_errors, xml_error)
  end
  luaunit.assertEquals(parser:parse(chunk), false)
  return xml_errors
end

function TestXMLSAXParser.test_xml_structured_error()
  local xml = [[
<?xml version="1.0"?>
<id>&aaa;</id>
]>
]]
  local expected = {
                     {
                       domain = ffi.C.XML_FROM_PARSER,
                       code = ffi.C.XML_ERR_UNDECLARED_ENTITY,
                       message = "Entity 'aaa' not defined\n",
                       level = ffi.C.XML_ERR_FATAL,
                       file = nil,
                       line = 2,
                    },
                   }
  luaunit.assertEquals(collect_xml_errors(xml), expected)
end

function TestXMLSAXParser.test_end_document()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<xml></xml>
]]
  local parser = xmlua.XMLSAXParser.new()
  local called = false
  parser.end_document = function()
    called = true
  end

  local succeeded = parser:parse(xml)
  luaunit.assertEquals({succeeded, called}, {true, false})
  succeeded = parser:finish()
  luaunit.assertEquals({succeeded, called}, {true, true})
end

function TestXMLSAXParser.test_add_sax_func()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<xml></xml>
]]
  local parser = xmlua.XMLSAXParser.new()
  local called = false
  parser:addSAXFunc("EndDocument",
                    function() called = true end)

  local succeeded = parser:parse(xml)
  luaunit.assertEquals({succeeded, called}, {true, false})
  succeeded = parser:finish()
  luaunit.assertEquals({succeeded, called}, {true, true})
end

function TestXMLSAXParser.test_update_sax_func()
  local xml = [[
<?xml version="1.0" encoding="UTF-8" ?>
<xml></xml>
]]
  local parser = xmlua.XMLSAXParser.new()
  local called = false
  local updated = false
  parser:addSAXFunc("EndDocument",
                    function() called = true end)
  parser:updateSAXFunc("EndDocument",
                    function() updated = true end)

  local succeeded = parser:parse(xml)
  luaunit.assertEquals({succeeded, called, updated}, {true, false, false})
  succeeded = parser:finish()
  luaunit.assertEquals({succeeded, called, updated}, {true, false, true})
end

