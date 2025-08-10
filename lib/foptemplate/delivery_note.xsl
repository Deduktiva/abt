<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:abt="http://deduktiva.com/Namespace/ABT/XSLT">

    <xsl:import href="document_base.xsl"/>

    <!-- Line item templates -->
    <xsl:template match="/document/items/item">
        <fo:table-body keep-together.within-page="always">
            <fo:table-row>
                <fo:table-cell padding-before="2mm">
                    <fo:block text-align="start"><xsl:value-of select="abt:strip-space(title)" /><xsl:if test="abt:strip-space(description) != ''">
                        <fo:block text-align="start" linefeed-treatment="preserve"><xsl:value-of select="abt:strip-space(description)" /></fo:block>
                    </xsl:if></fo:block>
                </fo:table-cell>
                <fo:table-cell padding-before="2mm">
                    <fo:block text-align="end"><xsl:value-of select="format-number(quantity, '###.##0,##', 'european')" /></fo:block>
                </fo:table-cell>
            </fo:table-row>
        </fo:table-body>
    </xsl:template>

    <xsl:template match="/document/items/text">
        <fo:table-body keep-together.within-page="always">
        <fo:table-row>
            <fo:table-cell number-columns-spanned="2">
                <xsl:if test="abt:strip-space(title) != ''">
                    <fo:block padding-before="2mm" text-align="start"><xsl:value-of select="abt:strip-space(title)" /></fo:block>
                </xsl:if>
                <xsl:if test="abt:strip-space(description) != ''">
                    <fo:block margin-left="5mm" padding-before="2mm" text-align="start" linefeed-treatment="preserve"><xsl:value-of select="abt:strip-space(description)" /></fo:block>
                </xsl:if>
                <xsl:if test="abt:strip-space(plain) != ''">
                    <fo:block margin-left="5mm" padding-before="2mm" text-align="start" linefeed-treatment="preserve" font-family="monospace"><xsl:value-of select="abt:strip-space(plain)" /></fo:block>
                </xsl:if>
            </fo:table-cell>
        </fo:table-row>
        </fo:table-body>
    </xsl:template>

    <xsl:template match="/document/items/subheading">
        <fo:table-body keep-together.within-page="always">
        <fo:table-row>
            <fo:table-cell number-columns-spanned="2">
                <fo:block padding-before="8mm" padding-after="2mm" text-align="start" font-weight="600">
                    <xsl:value-of select="abt:strip-space(title)" />
                </fo:block>
            </fo:table-cell>
        </fo:table-row>
        </fo:table-body>
    </xsl:template>

    <xsl:template match="/document/items">
        <xsl:apply-templates />
    </xsl:template>

    <!-- Delivery Note document -->
    <xsl:template match="/">
        <fo:root font-family="{$font-name-normal}">
            <fo:layout-master-set>
                <xsl:call-template name="standard-page-masters" />
            </fo:layout-master-set>

            <xsl:call-template name="pdf-metadata">
                <xsl:with-param name="document-type">
                    <xsl:choose>
                        <xsl:when test="/document/language = 'de'">Lieferschein</xsl:when>
                        <xsl:otherwise>Delivery</xsl:otherwise>
                    </xsl:choose>
                </xsl:with-param>
                <xsl:with-param name="document-number" select="/document/number" />
            </xsl:call-template>

            <fo:page-sequence master-reference="abt-document-master" id="document-sequence" font-family="{$font-name-normal}" font-weight="200" font-size="11pt" line-height="12pt">
                <fo:static-content flow-name="first-page-header">
                    <!-- Address blocks -->
                    <xsl:call-template name="sender-address-block" />
                    <xsl:call-template name="recipient-address-block" />

                    <!-- Right column: logo, document type, info boxes -->
                    <fo:block-container top="0cm" left="8.75cm" position="absolute">
                        <xsl:call-template name="company-header-block" />

                        <!-- Document type header -->
                        <fo:block-container height="1cm" width="8cm" top="3.25cm" position="absolute">
                            <fo:block text-align="start" font-family="{$font-name-display}" font-size="28pt" font-weight="700">
                                <xsl:choose>
                                    <xsl:when test="/document/language = 'de'">Lieferschein</xsl:when>
                                    <xsl:otherwise>Delivery</xsl:otherwise>
                                </xsl:choose>
                            </fo:block>
                        </fo:block-container>

                        <!-- Document key info -->
                        <fo:block-container top="4.25cm" position="absolute">

                            <fo:table table-layout="fixed" padding="0mm" margin="0mm">
                                <fo:table-column column-width="3cm"/>
                                <fo:table-column column-width="5cm"/>

                                <fo:table-body>
                                    <fo:table-row line-height="130%">
                                        <fo:table-cell>
                                            <fo:block font-family="{$font-name-display}" xsl:use-attribute-sets="accent-color">
                                                <xsl:choose>
                                                    <xsl:when test="/document/language = 'de'">Belegnummer:</xsl:when>
                                                    <xsl:otherwise>Document No:</xsl:otherwise>
                                                </xsl:choose>
                                            </fo:block>
                                        </fo:table-cell>
                                        <fo:table-cell>
                                            <fo:block>
                                                <xsl:value-of select="/document/number" />
                                            </fo:block>
                                        </fo:table-cell>
                                    </fo:table-row>
                                    <fo:table-row line-height="130%">
                                        <fo:table-cell>
                                            <fo:block font-family="{$font-name-display}" xsl:use-attribute-sets="accent-color">
                                                <xsl:choose>
                                                    <xsl:when test="/document/language = 'de'">Belegdatum:</xsl:when>
                                                    <xsl:otherwise>Document Date:</xsl:otherwise>
                                                </xsl:choose>
                                            </fo:block>
                                        </fo:table-cell>
                                        <fo:table-cell>
                                            <fo:block>
                                                <xsl:value-of select="abt:format-date(/document/issue-date, /document/language)"/>
                                            </fo:block>
                                        </fo:table-cell>
                                    </fo:table-row>
                                    <fo:table-row line-height="130%">
                                        <fo:table-cell>
                                            <fo:block font-family="{$font-name-display}" xsl:use-attribute-sets="accent-color">
                                                <xsl:choose>
                                                    <xsl:when test="/document/language = 'de'">Ihr Zeichen:</xsl:when>
                                                    <xsl:otherwise>Your Reference:</xsl:otherwise>
                                                </xsl:choose>
                                            </fo:block>
                                        </fo:table-cell>
                                        <fo:table-cell>
                                            <fo:block>
                                                <xsl:value-of select="/document/recipient/reference" />
                                            </fo:block>
                                        </fo:table-cell>
                                    </fo:table-row>
                                    <fo:table-row line-height="130%">
                                        <fo:table-cell>
                                            <fo:block font-family="{$font-name-display}" xsl:use-attribute-sets="accent-color">
                                                <xsl:choose>
                                                    <xsl:when test="/document/language = 'de'">Ihr Auftrag:</xsl:when>
                                                    <xsl:otherwise>Your Order No:</xsl:otherwise>
                                                </xsl:choose>
                                            </fo:block>
                                        </fo:table-cell>
                                        <fo:table-cell>
                                            <fo:block>
                                                <xsl:value-of select="/document/recipient/order-no" />
                                            </fo:block>
                                        </fo:table-cell>
                                    </fo:table-row>
                                </fo:table-body>
                            </fo:table>

                        </fo:block-container>
                    </fo:block-container>

                </fo:static-content>

                <fo:static-content flow-name="rest-page-header">
                    <!-- logo -->
                    <xsl:call-template name="company-logo-block"/>

                    <fo:block-container top="0cm" left="8.75cm" position="absolute">
                        <fo:block text-align="start" font-weight="100" font-size="8pt">
                            <xsl:choose>
                                <xsl:when test="/document/language = 'de'">Lieferschein</xsl:when>
                                <xsl:otherwise>Delivery Note</xsl:otherwise>
                            </xsl:choose>
                            <xsl:text> </xsl:text>
                            <xsl:value-of select="/document/number" />
                        </fo:block>
                    </fo:block-container>

                    <fo:block-container top="0cm" right="0cm" text-align="end" position="absolute">
                        <xsl:call-template name="page-x-of-y-text" />
                    </fo:block-container>
                </fo:static-content>

                <fo:static-content flow-name="any-page-footer">
                    <xsl:call-template name="folding-marks" />

                    <fo:block-container text-align="end">
                        <xsl:call-template name="page-x-of-y-text" />
                    </fo:block-container>
                </fo:static-content>

                <!-- Actual delivery note content -->
                <fo:flow flow-name="body">
                    <xsl:if test="/document/prelude != ''">
                        <fo:block-container space-after="18pt">
                            <fo:block linefeed-treatment="preserve">
                                <xsl:value-of select="abt:strip-space(/document/prelude)" />
                            </fo:block>
                        </fo:block-container>
                    </xsl:if>

                    <fo:table table-layout="fixed" width="100%" padding="0mm" margin="0mm">
                        <fo:table-column column-width="proportional-column-width(1)"/>
                        <fo:table-column column-width="1cm"/>
                        <fo:table-header>
                            <fo:table-row xsl:use-attribute-sets="accent-color">
                                <fo:table-cell>
                                    <fo:block text-align="start">
                                        <xsl:choose>
                                            <xsl:when test="/document/language = 'de'">Beschreibung</xsl:when>
                                            <xsl:otherwise>Description</xsl:otherwise>
                                        </xsl:choose>
                                    </fo:block>
                                </fo:table-cell>
                                <fo:table-cell>
                                    <fo:block text-align="end">
                                        <xsl:choose>
                                            <xsl:when test="/document/language = 'de'">Menge</xsl:when>
                                            <xsl:otherwise>Qty</xsl:otherwise>
                                        </xsl:choose>
                                    </fo:block>
                                </fo:table-cell>
                            </fo:table-row>
                        </fo:table-header>

                        <xsl:apply-templates select="/document/items" />
                    </fo:table>

                    <fo:block-container
                            border-before-style="solid" border-before-width="0.75pt" border-before-color="{/document/accent-color}"
                            space-before.optimum="1cm" space-before.minimum="0.2cm" space-before.maximum="2cm"
                            padding-before="0.5cm"
                            page-break-inside="avoid"
                            font-size="10pt" line-height="120%"
                            >
                        <fo:block font-size="18pt" line-height="22pt" font-weight="600">
                            <xsl:choose>
                                <xsl:when test="/document/language = 'de'">Lieferzeitraum</xsl:when>
                                <xsl:otherwise>Delivery Period</xsl:otherwise>
                            </xsl:choose>
                        </fo:block>
                        <fo:block>
                            <xsl:value-of select="/document/delivery-timeframe" />
                        </fo:block>
                    </fo:block-container>

                    <!-- signature box -->
                    <fo:block-container
                            border-before-style="solid" border-before-width="0.75pt" border-before-color="{/document/accent-color}"
                            space-before.optimum="1cm" space-before.minimum="0.2cm" space-before.maximum="2cm"
                            padding-before="0.5cm"
                            page-break-inside="avoid"
                            font-size="10pt" line-height="120%"
                            >
                        <fo:block font-size="18pt" line-height="22pt" font-weight="600">
                            <xsl:choose>
                                <xsl:when test="/document/language = 'de'">Abnahme der Lieferung (Endabnahme)</xsl:when>
                                <xsl:otherwise>Acceptance of Delivery</xsl:otherwise>
                            </xsl:choose>
                        </fo:block>
                        <fo:block text-align="justify">
                            <xsl:choose>
                                <xsl:when test="/document/language = 'de'">
                                    Die Lieferung wurde seitens des Auftragnehmers zeit- und leistungsgerecht vollständig erbracht;
                                    der Auftraggeber hat die Leistung getestet und abgenommen.
                                    Es erfolgt daher eine Freigabe der Zahlung durch den Auftraggeber.
                                </xsl:when>
                                <xsl:otherwise>
                                    The delivery has been completed by the contractor in full, on time and in accordance with specifications.
                                    The customer has tested and formally accepted the performance, as certified by their signature below.
                                    Payment is hereby approved and authorized.
                                </xsl:otherwise>
                            </xsl:choose>
                        </fo:block>
                        <fo:block padding-before="1mm" font-weight="300">
                            <xsl:choose>
                                <xsl:when test="/document/language = 'de'">Bestätigung der Abnahme durch den Kunden:</xsl:when>
                                <xsl:otherwise>Confirmation of Acceptance by Customer:</xsl:otherwise>
                            </xsl:choose>
                        </fo:block>

                        <!-- Signature fields table -->
                        <fo:block-container space-before="2.5cm">
                            <fo:block border-bottom="0.75pt solid {/document/accent-color}" height="1mm"/>
                        </fo:block-container>
                        <fo:block-container font-size="8pt">
                            <fo:block-container left="0cm" top="0mm" width="8.75cm" position="absolute">
                                <fo:block padding="1mm 1mm 1mm 1mm">
                                    <xsl:choose>
                                        <xsl:when test="/document/language = 'de'">Ort und Datum</xsl:when>
                                        <xsl:otherwise>Place and Date</xsl:otherwise>
                                    </xsl:choose>
                                </fo:block>
                            </fo:block-container>
                            <fo:block-container left="8.75cm" top="0mm" width="7cm" position="absolute">
                                <fo:block padding="1mm 1mm 1mm 1mm">
                                    <xsl:choose>
                                        <xsl:when test="/document/language = 'de'">Unterschrift des Kunden</xsl:when>
                                        <xsl:otherwise>Customer's Signature</xsl:otherwise>
                                    </xsl:choose>
                                </fo:block>
                            </fo:block-container>
                        </fo:block-container>

                    </fo:block-container>
                </fo:flow>
            </fo:page-sequence>
        </fo:root>
    </xsl:template>

</xsl:stylesheet>
