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
                    <fo:block text-align="start"><xsl:value-of select="abt:strip-space(title)" /></fo:block>
                </fo:table-cell>
                <fo:table-cell padding-before="2mm">
                    <fo:block text-align="end"><xsl:value-of select="format-number(quantity, '###.##0,##', 'european')" /></fo:block>
                </fo:table-cell>
                <fo:table-cell padding-before="2mm">
                    <fo:block text-align="end"><xsl:value-of select="abt:format-amount(rate)" /></fo:block>
                </fo:table-cell>
                <fo:table-cell padding-before="2mm">
                    <fo:block text-align="end"><xsl:value-of select="tax-class" /></fo:block>
                </fo:table-cell>
                <fo:table-cell padding-before="2mm">
                    <fo:block text-align="end"><xsl:value-of select="abt:format-amount(amount)" /></fo:block>
                </fo:table-cell>
            </fo:table-row>
            <xsl:if test="abt:strip-space(description) != ''">
                <fo:table-row>
                    <fo:table-cell padding-before="2mm" number-columns-spanned="5">
                        <fo:block margin-left="5mm" text-align="start" linefeed-treatment="preserve"><xsl:value-of select="abt:strip-space(description)" /></fo:block>
                    </fo:table-cell>
                </fo:table-row>
            </xsl:if>
        </fo:table-body>
    </xsl:template>

    <xsl:template match="/document/items/text">
        <fo:table-body keep-together.within-page="always">
        <fo:table-row>
            <fo:table-cell number-columns-spanned="5">
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
            <fo:table-cell number-columns-spanned="5">
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

    <!-- Tax class templates -->
    <xsl:template match="/document/sums/tax-classes/tax-class">
        <fo:table-row
                border-before-style="solid" border-before-width="0.13mm" border-before-color="black"
                space-before="1mm">
            <fo:table-cell number-columns-spanned="3" padding-before="1mm" padding-after="1mm">
                <fo:block text-align="start">
                    <xsl:choose>
                        <xsl:when test="/document/language = 'de'">Steuerklasse</xsl:when>
                        <xsl:otherwise>Tax Class</xsl:otherwise>
                    </xsl:choose>
                    ‟<xsl:value-of select="@name" />″:
		    <xsl:value-of select="abt:format-number(percentage)" />%
                    <xsl:choose>
                        <xsl:when test="/document/language = 'de'">von</xsl:when>
                        <xsl:otherwise>of</xsl:otherwise>
                    </xsl:choose>
                    <xsl:text> </xsl:text>
                    <xsl:value-of select="/document/currency" />
                    <xsl:text> </xsl:text>
                    <xsl:value-of select="abt:format-amount(sum)" />
                </fo:block>
            </fo:table-cell>
            <fo:table-cell padding-before="1mm" padding-after="1mm">
                <fo:block text-align="end"><xsl:value-of select="@indicator-code" /></fo:block>
            </fo:table-cell>
            <fo:table-cell padding-before="1mm" padding-after="1mm">
                <fo:block text-align="end"><xsl:value-of select="abt:format-amount(value)" /></fo:block>
            </fo:table-cell>
        </fo:table-row>
    </xsl:template>

    <xsl:template match="/document/sums/tax-classes">
        <xsl:apply-templates />
    </xsl:template>

    <!-- Invoice document -->
    <xsl:template match="/">
        <fo:root font-family="{$font-name-normal}">
            <fo:layout-master-set>
                <xsl:call-template name="standard-page-masters" />
            </fo:layout-master-set>

            <xsl:call-template name="pdf-metadata">
                <xsl:with-param name="document-type">Invoice</xsl:with-param>
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
                                    <xsl:when test="/document/language = 'de'">Rechnung</xsl:when>
                                    <xsl:otherwise>Invoice</xsl:otherwise>
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
                                                <xsl:value-of select="abt:format-date(/document/issue-date)"/>
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
                                    <fo:table-row line-height="130%">
                                        <fo:table-cell>
                                            <fo:block font-family="{$font-name-display}" xsl:use-attribute-sets="accent-color">
                                                <xsl:choose>
                                                    <xsl:when test="/document/language = 'de'">Ihre USt-IdNr.:</xsl:when>
                                                    <xsl:otherwise>Your VAT ID:</xsl:otherwise>
                                                </xsl:choose>
                                            </fo:block>
                                        </fo:table-cell>
                                        <fo:table-cell>
                                            <fo:block>
                                                <xsl:value-of select="/document/recipient/vat-id" />
                                            </fo:block>
                                        </fo:table-cell>
                                    </fo:table-row>
                                    <fo:table-row line-height="130%">
                                        <fo:table-cell>
                                            <fo:block font-family="{$font-name-display}" xsl:use-attribute-sets="accent-color">
                                                <xsl:choose>
                                                    <xsl:when test="/document/language = 'de'">Unsere USt-IdNr.:</xsl:when>
                                                    <xsl:otherwise>Our VAT ID:</xsl:otherwise>
                                                </xsl:choose>
                                            </fo:block>
                                        </fo:table-cell>
                                        <fo:table-cell>
                                            <fo:block>
                                                <xsl:value-of select="/document/issuer/vat-id" />
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
                                <xsl:when test="/document/language = 'de'">Rechnung</xsl:when>
                                <xsl:otherwise>Invoice</xsl:otherwise>
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

                <!-- Actual invoice content -->
                <fo:flow flow-name="body">
                    <xsl:if test="/document/prelude != ''">
                        <fo:block-container space-after="18pt">
                            <fo:block linefeed-treatment="preserve">
                                <xsl:value-of select="abt:strip-space(/document/prelude)" />
                            </fo:block>
                        </fo:block-container>
                    </xsl:if>

                    <fo:table table-layout="fixed" width="100%" padding="0mm" margin="0mm">
                        <fo:table-column column-width="11cm"/>
                        <fo:table-column column-width="1cm"/>
                        <fo:table-column column-width="2cm"/>
                        <fo:table-column column-width="1cm"/>
                        <fo:table-column column-width="2.25cm"/>
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
                                <fo:table-cell>
                                    <fo:block text-align="end">
                                        <xsl:choose>
                                            <xsl:when test="/document/language = 'de'">Preis</xsl:when>
                                            <xsl:otherwise>Rate</xsl:otherwise>
                                        </xsl:choose>
                                    </fo:block>
                                </fo:table-cell>
                                <fo:table-cell>
                                    <fo:block text-align="end">
                                        <xsl:choose>
                                            <xsl:when test="/document/language = 'de'">St-K</xsl:when>
                                            <xsl:otherwise>Tax</xsl:otherwise>
                                        </xsl:choose>
                                    </fo:block>
                                </fo:table-cell>
                                <fo:table-cell>
                                    <fo:block text-align="end">
                                        <xsl:choose>
                                            <xsl:when test="/document/language = 'de'">Gesamt</xsl:when>
                                            <xsl:otherwise>Amount</xsl:otherwise>
                                        </xsl:choose>
                                    </fo:block>
                                </fo:table-cell>
                            </fo:table-row>
                        </fo:table-header>

                        <xsl:apply-templates select="/document/items" />

                    </fo:table>

                    <!-- sum, tax classes, and total sum -->
                    <fo:block-container keep-together.within-page="always" space-before="4mm">

                        <xsl:if test="/document/tax-note != ''">
                            <fo:block-container>
                                <fo:block xsl:use-attribute-sets="accent-color">
                                    <xsl:choose>
                                        <xsl:when test="/document/language = 'de'">Steuerinformation</xsl:when>
                                        <xsl:otherwise>Tax Information</xsl:otherwise>
                                    </xsl:choose>
                                </fo:block>
                                <fo:block linefeed-treatment="preserve">
                                    <xsl:value-of select="abt:strip-space(/document/tax-note)" />
                                </fo:block>
                            </fo:block-container>
                        </xsl:if>

                        <fo:table table-layout="fixed" width="100%" space-before="1mm" padding="0mm" margin="0mm">
                            <fo:table-column column-width="11cm"/>
                            <fo:table-column column-width="1cm"/>
                            <fo:table-column column-width="2cm"/>
                            <fo:table-column column-width="1cm"/>
                            <fo:table-column column-width="2.25cm"/>

                            <fo:table-body>

                                <!-- sum (net) -->
                                <fo:table-row>
                                    <fo:table-cell number-columns-spanned="3" padding-before="1mm" padding-after="1mm">
                                        <fo:block text-align="start" font-style="italic">
                                            <xsl:choose>
                                                <xsl:when test="/document/language = 'de'">Summe</xsl:when>
                                                <xsl:otherwise>Sum</xsl:otherwise>
                                            </xsl:choose>
                                        </fo:block>
                                    </fo:table-cell>
                                    <fo:table-cell number-columns-spanned="2" padding-before="1mm" padding-after="1mm">
                                        <fo:block text-align="end" font-style="italic">
                                            <xsl:value-of select="abt:format-amount(/document/sums/net)" />
                                        </fo:block>
                                    </fo:table-cell>
                                </fo:table-row>

                                <xsl:apply-templates select="/document/sums/tax-classes" />

                                <!-- total -->
                                <fo:table-row
                                    border-before-style="solid" border-before-width="0.5mm" border-before-color="black"
                                    space-before="1mm">
                                    <fo:table-cell number-columns-spanned="3" padding-before="1mm" padding-after="1mm">
                                        <fo:block text-align="start">
                                            <fo:inline font-weight="600">
                                                <xsl:choose>
                                                    <xsl:when test="/document/language = 'de'">Gesamtsumme inkl. Steuer</xsl:when>
                                                    <xsl:otherwise>Total including tax</xsl:otherwise>
                                                </xsl:choose>
                                                <xsl:text> </xsl:text>
                                            </fo:inline>
                                            <fo:inline font-weight="normal">
                                                <xsl:choose>
                                                    <xsl:when test="/document/language = 'de'">fällig am</xsl:when>
                                                    <xsl:otherwise>due on</xsl:otherwise>
                                                </xsl:choose>
                                                <xsl:text> </xsl:text>
                                            </fo:inline>
                                            <fo:inline font-weight="600"><xsl:value-of select="abt:format-date(/document/due-date)" /></fo:inline>
                                        </fo:block>
                                    </fo:table-cell>
                                    <fo:table-cell number-columns-spanned="2" padding-before="1mm" padding-after="1mm">
                                        <fo:block text-align="end" font-weight="600">
                                            <xsl:value-of select="/document/currency"/>
                                            <xsl:text> </xsl:text>
                                            <xsl:value-of select="abt:format-amount(/document/sums/total)"/>
                                        </fo:block>
                                    </fo:table-cell>
                                </fo:table-row>
                            </fo:table-body>
                        </fo:table>
                    </fo:block-container>


                    <!-- end of document data -->
                    <fo:block-container space-before.optimum="0.5cm" space-before.minimum="0.5cm" space-before.maximum="1cm" line-height="120%" page-break-inside="avoid">
                        <fo:block-container
                                border-color="black" border-style="solid" border-width="0.13mm" padding="0.6mm">
                            <xsl:if test="/document/payment-url != ''">
                                <fo:block>
                                    <fo:inline font-weight="600">
                                        <xsl:choose>
                                            <xsl:when test="/document/language = 'de'">Online-Zahlung:</xsl:when>
                                            <xsl:otherwise>Online payment:</xsl:otherwise>
                                        </xsl:choose>
                                        <xsl:text> </xsl:text>
                                    </fo:inline>
                                    <fo:basic-link color="blue" external-destination="{/document/payment-url}"><xsl:value-of select="/document/payment-url" /></fo:basic-link>
                                </fo:block>
                            </xsl:if>
                            <fo:block>
                                <xsl:choose>
                                    <xsl:when test="/document/language = 'de'">Zahlungsanweisungen für</xsl:when>
                                    <xsl:otherwise>Payment instructions for</xsl:otherwise>
                                </xsl:choose>
                                <xsl:text> </xsl:text>
                                <fo:inline font-weight="600">
                                    <xsl:choose>
                                        <xsl:when test="/document/language = 'de'">Überweisung:</xsl:when>
                                        <xsl:otherwise>Wire transfer:</xsl:otherwise>
                                    </xsl:choose>
                                </fo:inline>
                            </fo:block>
                            <fo:block-container height="1.1cm">
                                <fo:block-container left="0cm" top="0mm" width="7cm" position="absolute">
                                    <fo:block>
                                        <fo:inline font-family="{$font-name-display}">
                                            <xsl:choose>
                                                <xsl:when test="/document/language = 'de'">Bank:</xsl:when>
                                                <xsl:otherwise>Bank:</xsl:otherwise>
                                            </xsl:choose>
                                            <xsl:text> </xsl:text>
                                        </fo:inline>
                                        <xsl:value-of select="/document/issuer/bankaccount/bank" />
                                    </fo:block>
                                    <fo:block>
                                        <fo:inline font-family="{$font-name-display}">
                                            BIC:
                                            <xsl:text> </xsl:text>
                                        </fo:inline>
                                        <xsl:value-of select="/document/issuer/bankaccount/bic" />
                                    </fo:block>
                                </fo:block-container>
                                <fo:block-container left="8.75cm" top="0mm" width="7cm" position="absolute">
                                    <fo:block>
                                        <fo:inline font-family="{$font-name-display}">
                                            <xsl:choose>
                                                <xsl:when test="/document/language = 'de'">Kontoinhaber:</xsl:when>
                                                <xsl:otherwise>Account Name:</xsl:otherwise>
                                            </xsl:choose>
                                            <xsl:text> </xsl:text>
                                        </fo:inline>
                                        <xsl:value-of select="/document/issuer/legal-name" />
                                    </fo:block>
                                    <fo:block>
                                        <fo:inline font-family="{$font-name-display}">
                                            <xsl:choose>
                                                <xsl:when test="/document/language = 'de'">Kontonummer:</xsl:when>
                                                <xsl:otherwise>Account No:</xsl:otherwise>
                                            </xsl:choose>
                                            <xsl:text> </xsl:text>
                                        </fo:inline>
                                        <xsl:value-of select="/document/issuer/bankaccount/number" />
                                    </fo:block>
                                </fo:block-container>
                            </fo:block-container>
                            <fo:block>
                                <xsl:choose>
                                    <xsl:when test="/document/language = 'de'">Bei Überweisungen von außerhalb des SEPA-Raums stellen Sie bitte sicher, dass der vollständige Betrag auf unserem Konto ankommt.</xsl:when>
                                    <xsl:otherwise>For transfers from outside the SEPA region, please ensure the full amount reaches our account.</xsl:otherwise>
                                </xsl:choose>
                            </fo:block>
                        </fo:block-container>

                        <fo:block space-before.optimum="0.5cm" space-before.minimum="0.5cm" space-before.maximum="1cm" text-align="justify" font-size="8pt" line-height="10pt">
                            <xsl:value-of select="/document/footer" />
                        </fo:block>
                    </fo:block-container>
                </fo:flow>
            </fo:page-sequence>
        </fo:root>
    </xsl:template>

</xsl:stylesheet>
