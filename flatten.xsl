<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="#all"
    xmlns="http://www.tei-c.org/ns/1.0" xpath-default-namespace="http://www.tei-c.org/ns/1.0"
    version="3.0">
    <xsl:output method="xml" indent="yes"/>
    <!--
        Note: Transformation must be run with Saxon PE or EE (not HE) to get Italian
            output from format-date()
        Workflow
            Note: Interim structures are in TEI namespace, but are not valid TEI
            1.  Flatten
                Description: flatten all elements, linking start and end tags with shared @tagId values
                Input: original XML
                Output: $flattened
            2.  Group
                Description: group contents of each page in <page> element
                Input: $flattened:
                Output: $grouped
                Note: Dates and titles are sometimes in the wrong pages
            3.  Date fix
                Description: move dates and titles into correct pages
                Input: $grouped
                Output: $date   
            4.  Map years to pages
                Description: create mapping of years to pages
                Input: $date
                Output: $page-chooser, page-chooser.xhtml
                Note: $page-chooser is serialized as navigation interface, and also used
                    to create separate HTML output for each year
            5.  Create HTML pages for each year
                Description: separate HTML file in pages-by-year subdirectory for each year's pages
                    Output is three column table: image, Italian, English
                Input: $date (contains <page> elements)
                Auxiliary input: $page-chooser (mapping from date to pages)
                Output: 1921.xhtml, etc. in pages-by-year subdirectory
                
    -->
    <xsl:template match="/">
        <!-- Flatten, group, and fix dates; save output in $date -->
        <xsl:variable name="flattened" as="element(wrapper)">
            <wrapper>
                <xsl:apply-templates select="descendant::div[@type eq 'transcription']/ab"
                    mode="flatten"/>
            </wrapper>
        </xsl:variable>
        <xsl:variable name="grouped" as="element(wrapper)">
            <wrapper>
                <xsl:for-each-group select="$flattened/node()" group-starting-with="pb">
                    <page>
                        <xsl:apply-templates select="current-group()" mode="grouped"/>
                    </page>
                </xsl:for-each-group>
            </wrapper>
        </xsl:variable>
        <xsl:variable name="date" as="element(wrapper)">
            <wrapper>
                <xsl:apply-templates select="$grouped" mode="date"/>
            </wrapper>
        </xsl:variable>
        <!-- 
            $date has been created, now do something with it
            create mapping of dates to pages first because it's needed to group dates by year 
        -->
        <!-- 
            Create HTML file that points from dates to pages
            Store as $page-chooser and serialize as page-chooser.xhtml
        -->
        <xsl:variable name="page-chooser" as="element(html:html)">
            <html xmlns="http://www.w3.org/1999/xhtml">
                <head>
                    <title>Hey, choose a meeting!</title>
                    <link type="text/css" rel="stylesheet" href="css/lega.css"/>
                </head>
                <body>
                    <h1>Hey, choose a meeting!</h1>
                    <ul id="page-chooser">
                        <xsl:for-each select="1 to count($date//date)">
                            <xsl:variable name="startDate"
                                select="($date//date)[position() eq current()]/@when"/>
                            <xsl:variable name="nextDate"
                                select="($date//date)[position() eq current() + 1]/@when"/>
                            <xsl:variable name="firstPage" as="xs:integer"
                                select="$startDate/ancestor::page/pb/@n"/>
                            <xsl:variable name="lastPage" as="xs:integer">
                                <xsl:choose>
                                    <xsl:when test="not($nextDate)">
                                        <xsl:value-of select="($date//page/pb)[last()]/@n"/>
                                    </xsl:when>
                                    <xsl:when
                                        test="$nextDate/ancestor::page/*[1][self::date[@when eq $nextDate]]">
                                        <xsl:value-of
                                            select="$nextDate/ancestor::page/preceding-sibling::page[1]/pb/@n"
                                        />
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="$nextDate/ancestor::page/pb/@n"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:variable>
                            <li data-pages="{$firstPage to $lastPage}">
                                <xsl:value-of
                                    select="format-date(xs:date($startDate), '[D1] [MNn] [Y1,4]', 'it', (), 'it')"
                                />
                            </li>
                        </xsl:for-each>
                    </ul>
                </body>
            </html>
        </xsl:variable>
        <xsl:result-document href="pages-by-meeting.xhtml" doctype-system="about:legacy-compat"
            method="xml" indent="yes" xmlns="http://www.w3.org/1999/xhtml">
            <xsl:sequence select="$page-chooser"/>
        </xsl:result-document>
        <!-- 
            Create HTML output for each year
            Output is a three-column table, with image, Italian, English columns (in that order)
            English is currently a placeholder, image is pointer in the form of 
                http://toscana.newtfire.org/img/meetingMinutes/5.png
            Variables:
                $page-numbers: page numbers for current year
                $pages: <page> elements (in pseudo-TEI namespace) for current year
        -->
        <xsl:for-each-group select="$page-chooser//html:li"
            group-by="substring(., string-length(.) - 3)">
            <!-- numbers of pages for the current year -->
            <xsl:variable name="page-numbers" as="xs:integer+"
                select="sort(distinct-values(current-group()/@data-pages/tokenize(., ' ')) ! xs:integer(.))"/>
            <!-- <page> elements (in pseudo-TEI namespace) for current year -->
            <xsl:variable name="pages" as="element(tei:page)+"
                select="$date//tei:page[pb/@n = $page-numbers]"/>
            <xsl:message select="count($pages)"/>
            <xsl:result-document method="xml" indent="yes" doctype-system="about:legacy-compat"
                xmlns="http://www.w3.org/1999/xhtml"
                href="{concat('pages-by-year/',current-grouping-key(),'.xhtml')}">
                <html>
                    <head>
                        <title>
                            <xsl:value-of select="concat('Minutes of ', current-grouping-key())"/>
                        </title>
                    </head>
                    <body>
                        <h1>
                            <xsl:value-of select="concat('Minutes of ', current-grouping-key())"/>
                        </h1>
                        <table>
                            <tr>
                                <th>Image</th>
                                <th>Transcription</th>
                                <th>Translation</th>
                            </tr>
                            <xsl:for-each select="$pages">
                                <tr>
                                    <td>Image</td>
                                    <td>Italian</td>
                                    <td>English</td>
                                </tr>
                            </xsl:for-each>
                        </table>
                    </body>
                </html>
            </xsl:result-document>
        </xsl:for-each-group>
    </xsl:template>
    <!-- Templates to flatten original input, output is $flattened -->
    <xsl:template match="ab" mode="flatten">
        <!-- 
            We process just the Italian <ab> elements, but fetch the entry <date> (obligatory)
            and <title> (optional, may include main and sub) from the <teiHeader>
            They may be in the wrong place; we move them later
        -->
        <xsl:copy-of select="ancestor::TEI//publicationStmt/date"/>
        <xsl:copy-of select="ancestor::TEI//titleStmt/title[not(empty(.))]"/>
        <xsl:apply-templates mode="flatten"/>
    </xsl:template>
    <!-- Ignore internal dates (e.g., committee dates); the only ones we care about are the meeting dates -->
    <xsl:template match="date" mode="flatten"/>
    <!-- 
        Flatten all elements, creating separate empty "start" and "end" tags (put attributes on both)
        Start and end tags share an @tagId, so that they can be re-erected later, if needed
    -->
    <xsl:template match="*" mode="flatten">
        <xsl:element name="{name()}">
            <xsl:attribute name="tagType" select="'startTag'"/>
            <xsl:attribute name="tagId" select="generate-id()"/>
            <xsl:copy-of select="@*"/>
        </xsl:element>
        <xsl:apply-templates mode="flatten"/>
        <xsl:if test="not(self::lb | self::pb | self::date)">
            <xsl:element name="{name()}">
                <xsl:attribute name="tagType" select="'endTag'"/>
                <xsl:attribute name="tagId" select="generate-id()"/>
                <xsl:copy-of select="@*"/>
            </xsl:element>
        </xsl:if>
    </xsl:template>
    <!-- End of templates to flatten original and create $flattened -->
    <!-- Templates to group by page, output is $grouped -->
    <xsl:template match="node() | @*" mode="grouped">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*" mode="grouped"/>
        </xsl:copy>
    </xsl:template>
    <!-- <lb> should come out as a single milestone with non attributes -->
    <xsl:template match="lb" mode="grouped">
        <xsl:element name="{name()}"/>
    </xsl:template>
    <!--  <pb> should come out as a single milestone with original attributes only -->
    <xsl:template match="pb" mode="grouped">
        <pb>
            <xsl:apply-templates select="@* except (@tagType | @tagId)" mode="grouped"/>
        </pb>
    </xsl:template>
    <!-- End of templates to group by page and created $grouped -->
    <!-- Templates to move stupid dates and titles, output is $date -->
    <xsl:template match="page" mode="date">
        <!-- Throw away most markup passively, by letting the built-in do the work -->
        <xsl:copy>
            <!--
                If the immediately preceding <page> ends in <date> and <title> elements, copy those into the current <page>
                (We'll also delete them from the preceding one, below)
            -->
            <xsl:copy-of
                select="preceding-sibling::page[1]/(date | title)[not(following-sibling::*[not(self::date | self::title)])]"/>
            <xsl:apply-templates mode="date"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="pb | del | unclear" mode="date">
        <!-- 
            <pb> contains @n for page number and @facs for image
            <del> and <unclear> may have content that we'll want to tag by restoring wrapper elements
        -->
        <xsl:copy-of select="."/>
    </xsl:template>
    <xsl:template match="lb" mode="date">
        <!-- remove any attributes from <lb>, which is necessarily empty -->
        <lb/>
    </xsl:template>
    <xsl:template match="date | title" mode="date">
        <!-- 
            Remove <date> and <title> elements at end of page
            We copy them (above) to the following page, effectively moving them
        -->
        <xsl:if test="following-sibling::*[not(self::title | self::date)]">
            <xsl:copy-of select="."/>
        </xsl:if>
    </xsl:template>
    <!-- End of templates to move dates and titles and create $date -->
</xsl:stylesheet>
