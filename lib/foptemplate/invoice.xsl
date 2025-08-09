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
                <fo:block padding-before="5mm" padding-after="5mm" text-align="start" font-weight="600">
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
        <fo:table-row>
            <fo:table-cell number-columns-spanned="3" padding-before="1mm" padding-after="1mm">
                <fo:block text-align="start">
                    Tax Class
                    <xsl:value-of select="@name" />:
                    <xsl:value-of select="percentage" />%
                    VAT of
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
        <fo:block-container
                border-before-style="solid" border-before-width="0.13mm" border-before-color="black"
                border-after-style="solid" border-after-width="0.13mm" border-after-color="black"
                space-before="5mm"
                >
            <fo:table table-layout="fixed" width="100%" padding="0mm" margin="0mm">
                <fo:table-column column-width="11cm"/>
                <fo:table-column column-width="1cm"/>
                <fo:table-column column-width="2cm"/>
                <fo:table-column column-width="1cm"/>
                <fo:table-column column-width="2.25cm"/>
                <fo:table-body>
                    <xsl:apply-templates />
                </fo:table-body>
            </fo:table>
        </fo:block-container>
    </xsl:template>

    <!-- Invoice document -->
    <xsl:template match="/">
        <fo:root font-family="sans-serif">
            <fo:layout-master-set>
                <xsl:call-template name="standard-page-masters" />
            </fo:layout-master-set>

            <xsl:call-template name="pdf-metadata">
                <xsl:with-param name="document-type">Invoice</xsl:with-param>
                <xsl:with-param name="document-number" select="/document/number" />
            </xsl:call-template>

            <fo:page-sequence master-reference="abt-document-master" id="document-sequence" font-family="OpenSans" font-weight="200" font-size="11pt" line-height="12pt">
                <fo:static-content flow-name="first-page-header">
                    <!-- Address blocks -->
                    <xsl:call-template name="sender-address-block" />
                    <xsl:call-template name="recipient-address-block" />

                    <!-- Right column: logo, document type, info boxes -->
                    <fo:block-container top="0cm" left="8.75cm" position="absolute">
                        <xsl:call-template name="company-header-block" />

                        <!-- Document type header -->
                        <fo:block-container height="1cm" width="8cm" top="2.8cm" position="absolute">
                            <fo:block text-align="start" font-size="23pt">
                                Invoice
                            </fo:block>
                        </fo:block-container>

                        <!-- first and second rows of info boxes -->
                        <fo:block-container top="4.25cm" position="absolute">
                            <xsl:call-template name="info-box">
                                <xsl:with-param name="label">Invoice No</xsl:with-param>
                                <xsl:with-param name="value" select="/document/number" />
                                <xsl:with-param name="top">0cm</xsl:with-param>
                                <xsl:with-param name="left">0cm</xsl:with-param>
                            </xsl:call-template>

                            <xsl:call-template name="info-box">
                                <xsl:with-param name="label">Date</xsl:with-param>
                                <xsl:with-param name="value" select="/document/issue-date" />
                                <xsl:with-param name="top">0cm</xsl:with-param>
                                <xsl:with-param name="left">4.375cm</xsl:with-param>
                            </xsl:call-template>

                            <!-- 2nd row -->
                            <xsl:call-template name="info-box">
                                <xsl:with-param name="label">Your Reference</xsl:with-param>
                                <xsl:with-param name="value" select="/document/recipient/reference" />
                                <xsl:with-param name="top">1.5cm</xsl:with-param>
                                <xsl:with-param name="left">0cm</xsl:with-param>
                            </xsl:call-template>

                            <xsl:call-template name="info-box">
                                <xsl:with-param name="label">Your Order No</xsl:with-param>
                                <xsl:with-param name="value" select="/document/recipient/order-no" />
                                <xsl:with-param name="top">1.5cm</xsl:with-param>
                                <xsl:with-param name="left">4.375cm</xsl:with-param>
                            </xsl:call-template>
                        </fo:block-container>
                    </fo:block-container>

                    <!-- full width line -->
                    <fo:block-container top="7.3cm" position="absolute">
                        <!--
                        <xsl:call-template name="info-box">
                            <xsl:with-param name="label">Account No</xsl:with-param>
                            <xsl:with-param name="value" select="/document/recipient/account-no" />
                            <xsl:with-param name="top">0cm</xsl:with-param>
                            <xsl:with-param name="left">0cm</xsl:with-param>
                        </xsl:call-template>

                        <xsl:call-template name="info-box">
                            <xsl:with-param name="label">Supplier No</xsl:with-param>
                            <xsl:with-param name="value" select="/document/recipient/supplier-no" />
                            <xsl:with-param name="top">0cm</xsl:with-param>
                            <xsl:with-param name="left">4.375cm</xsl:with-param>
                        </xsl:call-template>
                        -->

                        <xsl:call-template name="info-box">
                            <xsl:with-param name="label">Our VAT ID</xsl:with-param>
                            <xsl:with-param name="value" select="/document/issuer/vat-id" />
                            <xsl:with-param name="top">0cm</xsl:with-param>
                            <xsl:with-param name="left">8.75cm</xsl:with-param>
                        </xsl:call-template>

                        <xsl:call-template name="info-box">
                            <xsl:with-param name="label">Your VAT ID</xsl:with-param>
                            <xsl:with-param name="value" select="/document/recipient/vat-id" />
                            <xsl:with-param name="top">0cm</xsl:with-param>
                            <xsl:with-param name="left">13.125cm</xsl:with-param>
                        </xsl:call-template>
                    </fo:block-container>
                </fo:static-content>

                <fo:static-content flow-name="rest-page-header">
                    <!-- logo -->
                    <fo:block-container height="1cm" width="6cm" top="0cm" position="absolute">
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
                    </fo:block-container>

                    <fo:block-container top="0cm" left="8.75cm" position="absolute">
                        <fo:block text-align="start">
                            Invoice <xsl:value-of select="/document/number" />
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
                                    <fo:block text-align="start">Description</fo:block>
                                </fo:table-cell>
                                <fo:table-cell>
                                    <fo:block text-align="end">Qty</fo:block>
                                </fo:table-cell>
                                <fo:table-cell>
                                    <fo:block text-align="end">Rate</fo:block>
                                </fo:table-cell>
                                <fo:table-cell>
                                    <fo:block text-align="end">Tax</fo:block>
                                </fo:table-cell>
                                <fo:table-cell>
                                    <fo:block text-align="end">Amount</fo:block>
                                </fo:table-cell>
                            </fo:table-row>
                        </fo:table-header>

                        <xsl:apply-templates select="/document/items" />

                    </fo:table>

                    <!-- sum -->
                    <fo:block-container space-before="5mm">
                        <fo:table table-layout="fixed" width="100%" padding="0mm" margin="0mm">
                            <fo:table-column column-width="11cm"/>
                            <fo:table-column column-width="1cm"/>
                            <fo:table-column column-width="2cm"/>
                            <fo:table-column column-width="1cm"/>
                            <fo:table-column column-width="2.25cm"/>

                            <fo:table-body>
                                <fo:table-row>
                                    <fo:table-cell number-columns-spanned="3" padding-before="1mm" padding-after="1mm">
                                        <fo:block text-align="start" font-style="italic">Sum</fo:block>
                                    </fo:table-cell>
                                    <fo:table-cell number-columns-spanned="2" padding-before="1mm" padding-after="1mm">
                                        <fo:block text-align="end" font-style="italic">
                                            <xsl:value-of select="abt:format-amount(/document/sums/net)" />
                                        </fo:block>
                                    </fo:table-cell>
                                </fo:table-row>
                            </fo:table-body>
                        </fo:table>
                    </fo:block-container>

                    <!-- tax data -->
                    <xsl:apply-templates select="/document/sums/tax-classes" />

                    <xsl:if test="/document/tax-note != ''">
                        <fo:block-container space-before="2mm" space-after="2mm">
                            <fo:block xsl:use-attribute-sets="accent-color">Tax Information</fo:block>
                            <fo:block linefeed-treatment="preserve">
                                <xsl:value-of select="abt:strip-space(/document/tax-note)" />
                            </fo:block>
                        </fo:block-container>
                    </xsl:if>

                    <!-- total -->
                    <fo:block-container
                            border-before-style="solid" border-before-width="0.5mm" border-before-color="black"
                            border-after-style="solid" border-after-width="0.5mm" border-after-color="black"
                            space-before="2mm"
                            >
                        <fo:table table-layout="fixed" width="100%" padding="0mm" margin="0mm">
                            <fo:table-column column-width="11.25cm"/>
                            <fo:table-column column-width="1cm"/>
                            <fo:table-column column-width="2cm"/>
                            <fo:table-column column-width="1cm"/>
                            <fo:table-column column-width="2cm"/>

                            <fo:table-body>
                                <fo:table-row>
                                    <fo:table-cell number-columns-spanned="3" padding-before="1mm" padding-after="1mm">
                                        <fo:block text-align="start" font-weight="600">Total including tax</fo:block>
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
                    <fo:block-container space-before.optimum="1cm" space-before.minimum="0.5cm" space-before.maximum="1cm" line-height="15pt" page-break-inside="avoid">
                        <!-- note: can't have newline before first line -->

                        <fo:block-container
                                space-before="5mm" border-color="black" border-style="solid" border-width="0.13mm" padding="0.6mm">
                            <fo:block>Full amount due
                                <fo:inline font-weight="600">
                                    <xsl:value-of select="/document/currency"/>
                                    <xsl:text> </xsl:text>
                                    <xsl:value-of select="abt:format-amount(/document/sums/total)"/>
                                </fo:inline>
                                on
                                <fo:inline font-weight="600"><xsl:value-of select="/document/due-date" /></fo:inline>.
                            </fo:block>
                            <fo:block>
                                <xsl:if test="/document/payment-url != ''">
                                    <fo:inline font-weight="600">Online payment: </fo:inline>
                                    <fo:basic-link color="blue" external-destination="{/document/payment-url}"><xsl:value-of select="/document/payment-url" /></fo:basic-link>
                                </xsl:if>
                            </fo:block>
                            <fo:block><fo:inline font-weight="600">Wire transfer:</fo:inline></fo:block>
                            <fo:block-container height="1.1cm">
                                <fo:block-container left="0cm" top="0mm" width="7cm" position="absolute">
                                    <fo:block>Bank: <xsl:value-of select="/document/issuer/bankaccount/bank" /></fo:block>
                                    <fo:block>BIC: <xsl:value-of select="/document/issuer/bankaccount/bic" /></fo:block>
                                </fo:block-container>
                                <fo:block-container left="8.75cm" top="0mm" width="7cm" position="absolute">
                                    <fo:block>Account Name: <xsl:value-of select="/document/issuer/legal-name" /></fo:block>
                                    <fo:block>Account No: <xsl:value-of select="/document/issuer/bankaccount/number" /></fo:block>
                                </fo:block-container>
                            </fo:block-container>
                            <fo:block>For transfer from outside the SEPA region, please ensure the full amount reaches our account.</fo:block>
                        </fo:block-container>

                        <fo:block space-before="5mm" padding="0.6mm" text-align="justify" font-size="8pt" line-height="10pt">
                            <xsl:value-of select="/document/footer" />
                        </fo:block>
                    </fo:block-container>
                </fo:flow>
            </fo:page-sequence>
        </fo:root>
    </xsl:template>

</xsl:stylesheet>
