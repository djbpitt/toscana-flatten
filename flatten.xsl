<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="xs math"
    xmlns="http://www.tei-c.org/ns/1.0" xpath-default-namespace="http://www.tei-c.org/ns/1.0"
    version="3.0">
    <xsl:output method="xml" indent="yes"/>
    <xsl:template match="/">
        <xsl:variable name="flattened" as="document-node()">
            <xsl:document>
                <TEI>
                    <xsl:apply-templates select="descendant::div[@type eq 'transcription']/ab"
                        mode="flatten"/>
                </TEI>
            </xsl:document>
        </xsl:variable>
        <xsl:variable name="grouped" as="document-node()">
            <xsl:document>
                <TEI>
                    <xsl:for-each-group select="$flattened/TEI/node()" group-starting-with="pb">
                        <page>
                            <xsl:copy-of select="preceding-sibling::*[1][self::date]"/>
                            <xsl:copy-of select="current-group() except date"/>
                        </page>
                    </xsl:for-each-group>
                </TEI>
            </xsl:document>
        </xsl:variable>
        <xsl:sequence select="$grouped"/>
    </xsl:template>
    <!-- Templates to flatten original input, output is $flattened -->
    <xsl:template match="comment() | text()" mode="flatten">
        <xsl:copy-of select="."/>
    </xsl:template>
    <xsl:template match="ab" mode="flatten">
        <xsl:copy-of select="ancestor::TEI//publicationStmt/date"/>
        <xsl:apply-templates mode="flatten"/>
    </xsl:template>
    <xsl:template match="*" mode="flatten">
        <xsl:element name="{name()}">
            <xsl:copy-of select="@*"/>
        </xsl:element>
        <xsl:apply-templates select="node()" mode="flatten"/>
    </xsl:template>
    <!-- Templates to group by page, input is $flattened, output is $by-page -->

</xsl:stylesheet>
