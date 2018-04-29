<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="xs math"
    xmlns="http://www.tei-c.org/ns/1.0" xpath-default-namespace="http://www.tei-c.org/ns/1.0"
    version="3.0">
    <xsl:output method="xml" indent="yes"/>
    <xsl:template match="/">
        <xsl:variable name="flattened" as="element(wrapper)">
            <wrapper>
                <xsl:apply-templates select="descendant::div[@type='transcription']/ab"
                    mode="flatten"/>
                <xsl:apply-templates select="descendant::div[@type='translation']/ab"
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
        <xsl:sequence select="$date"/>
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
                        <xsl:for-each select="1 to count($date//date[parent::page[@lang='it']])">
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
        <xsl:copy-of select="ancestor::TEI//publicationStmt/date"/>
        <xsl:copy-of select="ancestor::TEI//titleStmt/title[not(empty(.))]"/>
        <xsl:apply-templates mode="flatten"/>
    </xsl:template>
    <xsl:template match="date" mode="flatten"/>
    <xsl:template match="*" mode="flatten">
        <xsl:element name="{name()}">
            <xsl:attribute name="tagType" select="'startTag'"/>
            <xsl:attribute name="tagId" select="generate-id()"/>
            <xsl:copy-of select="@*"/>
            <xsl:choose>
                <xsl:when test="self::pb[ancestor::div[@type='transcription']]">
                    <xsl:attribute name="lang">it</xsl:attribute>
                </xsl:when>
                <xsl:when test="self::pb[ancestor::div[@type='translation']]">
                    <xsl:attribute name="lang">eng</xsl:attribute>
                </xsl:when>
            </xsl:choose>
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
    <!-- Templates to output groups by page -->
    <xsl:template match="node() | @*" mode="grouped">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*" mode="grouped"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="lb" mode="grouped">
        <xsl:element name="{name()}"/>
    </xsl:template>
    <xsl:template match="pb" mode="grouped">
        <pb>
            <xsl:apply-templates select="@* except (@tagType | @tagId)" mode="grouped"/>
        </pb>
    </xsl:template>
    <!-- Templates to move stupid dates -->
    <xsl:template match="page" mode="date">
        <xsl:copy>
            <xsl:attribute name="lang"><xsl:value-of select="child::pb/@lang"/></xsl:attribute>
            <xsl:copy-of
                select="preceding-sibling::page[1]/(date | title)[not(following-sibling::*[not(self::date | self::title)])]"/>
            <xsl:apply-templates mode="date"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="del | unclear" mode="date">
        <xsl:copy-of select="."/>
    </xsl:template>
    <xsl:template match="pb" mode="date">
<xsl:copy>
    <xsl:copy-of select="@* except @lang"/>
</xsl:copy>
    </xsl:template>
    <xsl:template match="lb" mode="date">
        <lb/>
    </xsl:template>
    <xsl:template match="date | title" mode="date">
        <xsl:if test="following-sibling::*[not(self::title | self::date)]">
            <xsl:copy-of select="."/>
        </xsl:if>
    </xsl:template>
</xsl:stylesheet>
