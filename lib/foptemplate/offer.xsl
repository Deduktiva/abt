<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:abt="http://deduktiva.com/Namespace/ABT/XSLT">

    <xsl:import href="document_base.xsl"/>


    <!-- Milestone table templates -->
    <xsl:template match="/document/milestones">
        <fo:table-body>
            <xsl:apply-templates select="milestone" />
        </fo:table-body>
    </xsl:template>

    <xsl:template match="/document/milestones/milestone">
        <fo:table-row keep-together.within-page="always">
            <fo:table-cell padding-before="2mm">
                <fo:block text-align="start" font-weight="600">
                    <xsl:if test="count(/document/milestones/milestone) &gt; 1">
                        <xsl:text>Position </xsl:text>
                        <xsl:value-of select="position()" />
                        <xsl:text>: </xsl:text>
                    </xsl:if>
                    <xsl:value-of select="abt:strip-space(title)" />
                </fo:block>
                <xsl:if test="abt:strip-space(description) != ''">
                    <fo:block margin-left="4mm" font-size="9pt" linefeed-treatment="preserve"><xsl:value-of select="abt:strip-space(description)" /></fo:block>
                </xsl:if>
            </fo:table-cell>
            <fo:table-cell padding-before="2mm">
                <fo:block text-align="start">
                    <xsl:choose>
                        <xsl:when test="trigger = 'on_order'">
                            <xsl:choose>
                                <xsl:when test="/document/language = 'de'">Bei Auftrag</xsl:when>
                                <xsl:otherwise>Upon order</xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:when test="trigger = 'on_acceptance'">
                            <xsl:choose>
                                <xsl:when test="/document/language = 'de'">Bei Abnahme</xsl:when>
                                <xsl:otherwise>Upon acceptance</xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="abt:format-date(trigger-date, /document/language)" />
                        </xsl:otherwise>
                    </xsl:choose>
                </fo:block>
            </fo:table-cell>
            <fo:table-cell padding-before="2mm">
                <fo:block text-align="end">
                    <xsl:value-of select="/document/currency" />
                    <xsl:text> </xsl:text>
                    <xsl:value-of select="abt:format-amount(amount)" />
                </fo:block>
            </fo:table-cell>
        </fo:table-row>
    </xsl:template>

    <!-- Offer document -->
    <xsl:template match="/">
        <fo:root font-family="{$font-name-normal}">
            <fo:layout-master-set>
                <xsl:call-template name="standard-page-masters">
                    <xsl:with-param name="first-body-margin-top" select="'6.5cm'" />
                </xsl:call-template>
            </fo:layout-master-set>

            <xsl:call-template name="pdf-metadata">
                <xsl:with-param name="document-type">Offer</xsl:with-param>
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
                                    <xsl:when test="/document/language = 'de'">Angebot</xsl:when>
                                    <xsl:otherwise>Offer</xsl:otherwise>
                                </xsl:choose>
                            </fo:block>
                        </fo:block-container>

                        <!-- Document key info -->
                        <fo:block-container top="4.25cm" position="absolute">

                            <fo:table table-layout="fixed" padding="0mm" margin="0mm">
                                <fo:table-column column-width="3cm"/>
                                <fo:table-column column-width="5cm"/>

                                <fo:table-body>
                                    <xsl:if test="normalize-space(/document/number) != ''">
                                        <fo:table-row line-height="130%">
                                            <fo:table-cell>
                                                <fo:block font-family="{$font-name-display}" xsl:use-attribute-sets="accent-color">
                                                    <xsl:choose>
                                                        <xsl:when test="/document/language = 'de'">Nummer:</xsl:when>
                                                        <xsl:otherwise>Document No:</xsl:otherwise>
                                                    </xsl:choose>
                                                </fo:block>
                                            </fo:table-cell>
                                            <fo:table-cell>
                                                <fo:block>
                                                    <xsl:value-of select="/document/number" />
                                                    <xsl:if test="/document/version-number">
                                                        <xsl:text> v</xsl:text>
                                                        <xsl:value-of select="/document/version-number" />
                                                    </xsl:if>
                                                </fo:block>
                                            </fo:table-cell>
                                        </fo:table-row>
                                    </xsl:if>
                                    <fo:table-row line-height="130%">
                                        <fo:table-cell>
                                            <fo:block font-family="{$font-name-display}" xsl:use-attribute-sets="accent-color">
                                                <xsl:choose>
                                                    <xsl:when test="/document/language = 'de'">Angebotsdatum:</xsl:when>
                                                    <xsl:otherwise>Date:</xsl:otherwise>
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
                                                    <xsl:when test="/document/language = 'de'">Gültig bis:</xsl:when>
                                                    <xsl:otherwise>Valid until:</xsl:otherwise>
                                                </xsl:choose>
                                            </fo:block>
                                        </fo:table-cell>
                                        <fo:table-cell>
                                            <fo:block>
                                                <xsl:value-of select="abt:format-date(/document/valid-until, /document/language)"/>
                                            </fo:block>
                                        </fo:table-cell>
                                    </fo:table-row>
                                    <xsl:if test="normalize-space(/document/delivery-date) != ''">
                                        <fo:table-row line-height="130%">
                                            <fo:table-cell>
                                                <fo:block font-family="{$font-name-display}" xsl:use-attribute-sets="accent-color">
                                                    <xsl:choose>
                                                        <xsl:when test="/document/language = 'de'">Liefertermin:</xsl:when>
                                                        <xsl:otherwise>Delivery date:</xsl:otherwise>
                                                    </xsl:choose>
                                                </fo:block>
                                            </fo:table-cell>
                                            <fo:table-cell>
                                                <fo:block>
                                                    <xsl:value-of select="abt:format-date(/document/delivery-date, /document/language)"/>
                                                </fo:block>
                                            </fo:table-cell>
                                        </fo:table-row>
                                    </xsl:if>
                                    <xsl:if test="normalize-space(/document/recipient/supplier-no) != ''">
                                        <fo:table-row line-height="130%">
                                            <fo:table-cell>
                                                <fo:block font-family="{$font-name-display}" xsl:use-attribute-sets="accent-color">
                                                    <xsl:choose>
                                                        <xsl:when test="/document/language = 'de'">Kreditorennr.:</xsl:when>
                                                        <xsl:otherwise>Supplier No.:</xsl:otherwise>
                                                    </xsl:choose>
                                                </fo:block>
                                            </fo:table-cell>
                                            <fo:table-cell>
                                                <fo:block>
                                                    <xsl:value-of select="/document/recipient/supplier-no" />
                                                </fo:block>
                                            </fo:table-cell>
                                        </fo:table-row>
                                    </xsl:if>
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
                                <xsl:when test="/document/language = 'de'">Angebot</xsl:when>
                                <xsl:otherwise>Offer</xsl:otherwise>
                            </xsl:choose>
                            <xsl:text> </xsl:text><xsl:value-of select="/document/number" />
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

                <!-- Actual offer content -->
                <fo:flow flow-name="body">
                    <!-- Subject line -->
                    <xsl:if test="abt:strip-space(/document/subject) != ''">
                        <fo:block-container space-after="12pt">
                            <fo:block font-family="{$font-name-display}" font-size="13pt" font-weight="600">
                                <xsl:value-of select="abt:strip-space(/document/subject)" />
                            </fo:block>
                        </fo:block-container>
                    </xsl:if>

                    <xsl:if test="/document/prelude/*">
                        <!-- 12pt = one body line, so the gap reads as a single empty line -->
                        <fo:block-container space-after="12pt">
                            <xsl:copy-of select="/document/prelude/*" />
                        </fo:block-container>
                    </xsl:if>

                    <xsl:if test="/document/boilerplate/*">
                        <fo:block-container space-after="18pt">
                            <xsl:copy-of select="/document/boilerplate/*" />
                        </fo:block-container>
                    </xsl:if>

                    <!-- Milestone table -->
                    <fo:table table-layout="fixed" width="100%" padding="0mm" margin="0mm">
                        <fo:table-column column-width="11cm"/>
                        <fo:table-column column-width="3.25cm"/>
                        <fo:table-column column-width="3cm"/>
                        <fo:table-header>
                            <fo:table-row xsl:use-attribute-sets="accent-color">
                                <fo:table-cell>
                                    <fo:block text-align="start">
                                        <xsl:if test="count(/document/milestones/milestone) &gt; 1">
                                            <xsl:choose>
                                                <xsl:when test="/document/language = 'de'">Meilensteine</xsl:when>
                                                <xsl:otherwise>Milestones</xsl:otherwise>
                                            </xsl:choose>
                                        </xsl:if>
                                    </fo:block>
                                </fo:table-cell>
                                <fo:table-cell>
                                    <fo:block text-align="start">
                                        <xsl:choose>
                                            <xsl:when test="/document/language = 'de'">Fällig</xsl:when>
                                            <xsl:otherwise>Payment Due</xsl:otherwise>
                                        </xsl:choose>
                                    </fo:block>
                                </fo:table-cell>
                                <fo:table-cell>
                                    <fo:block text-align="end">
                                        <xsl:choose>
                                            <xsl:when test="/document/language = 'de'">Betrag Netto</xsl:when>
                                            <xsl:otherwise>Amount Netto</xsl:otherwise>
                                        </xsl:choose>
                                    </fo:block>
                                </fo:table-cell>
                            </fo:table-row>
                        </fo:table-header>

                        <xsl:apply-templates select="/document/milestones" />

                    </fo:table>

                    <fo:block space-before.optimum="0.5cm" space-before.minimum="0.5cm" space-before.maximum="1cm" text-align="justify" font-size="8pt" line-height="10pt">
                        <xsl:value-of select="/document/footer" />
                    </fo:block>
                </fo:flow>
            </fo:page-sequence>
        </fo:root>
    </xsl:template>

</xsl:stylesheet>
