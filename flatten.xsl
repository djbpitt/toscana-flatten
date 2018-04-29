<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="xs math"
    xmlns="http://www.tei-c.org/ns/1.0" xpath-default-namespace="http://www.tei-c.org/ns/1.0"
    version="3.0">
    <!-- eng branch copy -->
    <!-- 2018-04-29 zme -->
    <xsl:output method="xml" indent="yes"/>
    <!--
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
            4.  
    -->
    <xsl:template match="/">
        <!-- Flatten, group, and fix dates; save output in $date -->
        <xsl:variable name="flattened" as="element(wrapper)">
            <wrapper>
                <xsl:apply-templates select="descendant::div/ab" mode="flatten"/>
            </wrapper>
        </xsl:variable>
        <xsl:variable name="grouped" as="element(wrapper)">
            <wrapper>
                <xsl:for-each-group select="$flattened/node()" group-starting-with="pb">
                    <xsl:choose>
                        <xsl:when test="ancestor::div[@type = 'transcription']">
                            <page lang="it">
                                <xsl:apply-templates select="current-group()" mode="grouped"/>
                            </page>
                        </xsl:when>
                        <xsl:otherwise>
                            <page lang="eng">
                                <xsl:apply-templates select="current-group()" mode="grouped"/>
                            </page>
                        </xsl:otherwise>
                    </xsl:choose>

                </xsl:for-each-group>
            </wrapper>
        </xsl:variable>
        <xsl:variable name="date" as="element(wrapper)">
            <wrapper>
                <xsl:apply-templates select="$grouped" mode="date"/>
            </wrapper>
        </xsl:variable>
        <!-- $date has been created, now do something with it -->
        <!-- Temporarily write date-fixed pages to stdout-->
        <xsl:sequence select="$date"/>
        <!-- Create HTML file that points from dates to pages -->
        <xsl:result-document href="pages-by-meeting.xhtml" doctype-system="about:legacy-compat"
            method="xml" indent="yes" xmlns="http://www.w3.org/1999/xhtml">
            <html>
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
        </xsl:result-document>
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
