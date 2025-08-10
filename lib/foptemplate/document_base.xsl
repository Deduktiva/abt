<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:abt="http://deduktiva.com/Namespace/ABT/XSLT">
    <xsl:output method="xml" indent="yes"/>
    <xsl:strip-space elements="*" />
    <xsl:decimal-format name="european" decimal-separator=',' grouping-separator='.' />

    <!-- Common definitions -->
    <xsl:variable name="font-name-normal">Inter</xsl:variable>
    <xsl:variable name="font-name-display">InterDisplay</xsl:variable>

    <!-- Common utility functions -->
    <xsl:function name="abt:strip-space">
        <xsl:param name="string" />
        <xsl:value-of select="replace($string, '^\s+|\s+$', '')" />
    </xsl:function>

    <xsl:function name="abt:format-amount">
        <xsl:param name="value" />
        <xsl:value-of select="format-number($value, '###.##0,00', 'european')" />
    </xsl:function>

    <xsl:function name="abt:format-date">
        <xsl:param name="value" />
        <xsl:value-of select="format-date($value, '[D01] [MNn] [Y0001]')" />
    </xsl:function>

    <xsl:function name="abt:ifempty">
        <xsl:param name="string" />
        <xsl:param name="empty" />
        <xsl:param name="filled" />
        <xsl:choose>
            <xsl:when test="$string != ''">
                <xsl:value-of select="$filled" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$empty" />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- Common attribute sets -->
    <xsl:attribute-set name="accent-color">
        <xsl:attribute name="color"><xsl:value-of select="/document/accent-color" /></xsl:attribute>
    </xsl:attribute-set>

    <!-- Page master templates -->
    <xsl:template name="standard-page-masters">
        <fo:simple-page-master master-name="first"
                               margin-left="2.25cm"
                               margin-top="1.5cm"
                               margin-right="1.5cm"
                               margin-bottom="1.5cm"
                               page-width="21cm"
                               page-height="29.7cm">
            <fo:region-body region-name="body" margin-top="8.5cm" margin-bottom="0.2cm" />
            <fo:region-before region-name="first-page-header" />
            <fo:region-after region-name="any-page-footer" />
        </fo:simple-page-master>

        <fo:simple-page-master master-name="rest"
                               margin-left="2.25cm"
                               margin-top="0.75cm"
                               margin-right="1.5cm"
                               margin-bottom="1.5cm"
                               page-width="21cm"
                               page-height="29.7cm">
            <fo:region-body region-name="body" margin-top="2cm" margin-bottom="2cm" />
            <fo:region-before region-name="rest-page-header" />
            <fo:region-after region-name="any-page-footer" />
        </fo:simple-page-master>

        <fo:page-sequence-master master-name="abt-document-master">
          <fo:repeatable-page-master-alternatives>
            <fo:conditional-page-master-reference master-reference="first"
              page-position="first" />
            <fo:conditional-page-master-reference master-reference="rest"
              page-position="rest" />
            <!-- recommended fallback procedure -->
            <fo:conditional-page-master-reference master-reference="rest" />
          </fo:repeatable-page-master-alternatives>
        </fo:page-sequence-master>
    </xsl:template>

    <!-- Component: sender address block -->
    <xsl:template name="sender-address-block">
        <fo:block-container height="3cm" width="12cm" top="0cm" left="0cm" position="absolute">
            <!-- note: can't have linefeed before first line -->
            <fo:block linefeed-treatment="preserve">
                <xsl:value-of select="abt:strip-space(/document/issuer/address)" />
            </fo:block>
        </fo:block-container>

        <fo:block-container height="0.5cm" width="12cm" top="3cm" left="0cm" position="absolute" font-size="6pt">
            <!-- inline sender -->
            <fo:block xsl:use-attribute-sets="accent-color" font-family="{$font-name-display}" font-weight="normal">
                Returns to: <xsl:value-of select="replace(abt:strip-space(/document/issuer/address), '\n', ', ')" />
            </fo:block>
        </fo:block-container>
    </xsl:template>

    <!-- Component: recipient address block -->
    <xsl:template name="recipient-address-block">
        <fo:block-container height="3cm" width="8.95cm" top="3.5cm" left="0cm" position="absolute">
            <!-- note: can't have linefeed before first line -->
            <fo:block linefeed-treatment="preserve">
                <xsl:value-of select="abt:strip-space(/document/recipient/address)" />
            </fo:block>
        </fo:block-container>
    </xsl:template>

    <!-- implementation detail: logo only -->
    <xsl:template name="impl-company-logo">
        <fo:block text-align="start" font-size="12pt" xsl:use-attribute-sets="accent-color">
            <xsl:choose>
                <xsl:when test="/document/logo-path">
                    <fo:external-graphic src="{/document/logo-path}"
                        content-width="{/document/logo-width}"
                        content-height="{/document/logo-height}"
                        scaling="uniform" />
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="/document/issuer/legal-name" />
                </xsl:otherwise>
            </xsl:choose>
        </fo:block>
    </xsl:template>

    <!-- Component: company logo/name block with contact lines (typically on first page) -->
    <xsl:template name="company-header-block">
        <fo:block-container height="1cm" width="6cm" top="0cm" left="0cm" position="absolute" line-height="120%">
            <xsl:call-template name="impl-company-logo"/>

            <fo:block text-align="start" font-size="9pt" xsl:use-attribute-sets="accent-color">
                <fo:block white-space-collapse="false">
                    <xsl:value-of select="abt:strip-space(/document/issuer/contact-line1)" />
                </fo:block>
                <fo:block white-space-collapse="false">
                    <xsl:value-of select="abt:strip-space(/document/issuer/contact-line2)" />
                </fo:block>
            </fo:block>
        </fo:block-container>
    </xsl:template>

    <!-- Component: company logo/name block without contact lines -->
    <xsl:template name="company-logo-block">
        <!-- logo -->
        <fo:block-container height="1cm" width="6cm" top="0cm" left="0cm" position="absolute">
            <xsl:call-template name="impl-company-logo"/>
        </fo:block-container>
    </xsl:template>

    <!-- Component: info box template -->
    <xsl:template name="info-box">
        <xsl:param name="label" />
        <xsl:param name="value" />
        <xsl:param name="width" select="'4.1cm'" />
        <xsl:param name="top" select="'0cm'" />
        <xsl:param name="left" select="'0cm'" />

        <fo:block-container position="absolute" width="{$width}" top="{$top}" left="{$left}">
            <fo:block xsl:use-attribute-sets="accent-color"><xsl:value-of select="$label" /></fo:block>
            <fo:block><xsl:value-of select="$value" /></fo:block>
        </fo:block-container>
    </xsl:template>

    <!-- Component: folding marks -->
    <xsl:template name="folding-marks">
        <fo:block-container>
            <fo:block-container width="0.5cm"
                                top="9.6cm" left="0.8cm"
                                position="fixed"
                                overflow="visible"
                                color="#999999">
                <fo:block>
                    <fo:leader leader-length.minimum="100%" leader-length.optimum="100%" leader-pattern="rule" rule-thickness="0.13mm"/>
                </fo:block>
            </fo:block-container>

            <fo:block-container width="0.5cm"
                                top="19.5cm" left="0.8cm"
                                position="fixed"
                                overflow="visible"
                                color="#999999">
                <fo:block>
                    <fo:leader leader-length.minimum="100%" leader-length.optimum="100%" leader-pattern="rule" rule-thickness="0.13mm"/>
                </fo:block>
            </fo:block-container>
        </fo:block-container>
    </xsl:template>

    <!-- Component: Page X of Y text -->
    <xsl:template name="page-x-of-y-text">
        <fo:block font-weight="100" font-size="8pt">
            Page <fo:page-number/> of <fo:page-number-citation-last ref-id="document-sequence"/>
        </fo:block>
    </xsl:template>

    <!-- Common PDF metadata template -->
    <xsl:template name="pdf-metadata">
        <xsl:param name="document-type" select="'Document'" />
        <xsl:param name="document-number" />

        <fo:declarations>
            <x:xmpmeta xmlns:x="adobe:ns:meta/">
                <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                    <rdf:Description rdf:about=""
                        xmlns:dc="http://purl.org/dc/elements/1.1/"
                        xmlns:xmp="http://ns.adobe.com/xap/1.0/"
                        xmlns:pdf="http://ns.adobe.com/pdf/1.3/"
                        xmlns:pdfaid="http://www.aiim.org/pdfa/ns/id/">
                        <dc:title>
                            <rdf:Alt>
                                <rdf:li xml:lang="x-default"><xsl:value-of select="/document/issuer/short-name"/> <xsl:value-of select="$document-type" /> <xsl:value-of select="$document-number" /></rdf:li>
                            </rdf:Alt>
                        </dc:title>
                        <dc:creator>
                            <rdf:Seq>
                                <rdf:li><xsl:value-of select="/document/issuer/legal-name"/></rdf:li>
                            </rdf:Seq>
                        </dc:creator>
                        <dc:description>
                            <rdf:Alt>
                                <rdf:li xml:lang="x-default"><xsl:value-of select="$document-type" /> <xsl:value-of select="$document-number" /></rdf:li>
                            </rdf:Alt>
                        </dc:description>
                        <dc:format>application/pdf</dc:format>
                        <dc:subject>
                            <rdf:Bag>
                                <rdf:li><xsl:value-of select="$document-type" /></rdf:li>
                            </rdf:Bag>
                        </dc:subject>
                        <xmp:CreatorTool>Apache FOP</xmp:CreatorTool>
                        <xmp:CreateDate><xsl:value-of select="/document/issue-date"/>T00:00:00Z</xmp:CreateDate>
                        <xmp:ModifyDate><xsl:value-of select="/document/issue-date"/>T00:00:00Z</xmp:ModifyDate>
                        <xmp:MetadataDate><xsl:value-of select="/document/issue-date"/>T00:00:00Z</xmp:MetadataDate>
                        <pdf:Producer>Apache FOP</pdf:Producer>
                        <pdf:Keywords><xsl:value-of select="$document-type" /></pdf:Keywords>
                        <pdfaid:part>1</pdfaid:part>
                        <pdfaid:conformance>B</pdfaid:conformance>
                    </rdf:Description>
                </rdf:RDF>
            </x:xmpmeta>
        </fo:declarations>
    </xsl:template>

</xsl:stylesheet>
