<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:abt="http://deduktiva.com/Namespace/ABT/XSLT">

    <!-- Import base document template -->
    <xsl:import href="document_base.xsl"/>

    <!-- Invoice-specific line item templates -->
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

    <!-- Invoice-specific tax class templates -->
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

    <!-- Main invoice template -->
    <xsl:template match="/">
        <fo:root font-family="sans-serif">
            <fo:layout-master-set>
                <xsl:call-template name="standard-page-masters" />
            </fo:layout-master-set>

            <xsl:call-template name="pdf-metadata">
                <xsl:with-param name="document-type">Invoice</xsl:with-param>
                <xsl:with-param name="document-number" select="/document/number" />
            </xsl:call-template>

            <fo:page-sequence master-reference="psmA" id="document-sequence" font-family="OpenSans" font-weight="200" font-size="11pt" line-height="12pt">
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

                        <!-- Invoice info boxes -->
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

                            <xsl:call-template name="info-box">
                                <xsl:with-param name="label">Your Reference</xsl:with-param>
                                <xsl:with-param name="value" select="/document/reference" />
                                <xsl:with-param name="top">1.5cm</xsl:with-param>
                                <xsl:with-param name="left">0cm</xsl:with-param>
                            </xsl:call-template>

                            <xsl:call-template name="info-box">
                                <xsl:with-param name="label">Your Order No</xsl:with-param>
                                <xsl:with-param name="value" select="/document/order" />
                                <xsl:with-param name="top">1.5cm</xsl:with-param>
                                <xsl:with-param name="left">4.375cm</xsl:with-param>
                            </xsl:call-template>

                            <xsl:call-template name="info-box">
                                <xsl:with-param name="label">Project</xsl:with-param>
                                <xsl:with-param name="value" select="/document/project" />
                                <xsl:with-param name="top">3cm</xsl:with-param>
                                <xsl:with-param name="left">0cm</xsl:with-param>
                            </xsl:call-template>

                            <xsl:call-template name="info-box">
                                <xsl:with-param name="label">Due Date</xsl:with-param>
                                <xsl:with-param name="value" select="/document/due-date" />
                                <xsl:with-param name="top">3cm</xsl:with-param>
                                <xsl:with-param name="left">4.375cm</xsl:with-param>
                            </xsl:call-template>
                        </fo:block-container>
                    </fo:block-container>
                </fo:static-content>

                <!-- Invoice-specific footer -->
                <fo:static-content flow-name="any-page-footer">
                    <fo:block font-size="9pt" text-align="center" color="black" linefeed-treatment="preserve">
                        <xsl:value-of select="abt:strip-space(/document/footer)" />
                    </fo:block>
                </fo:static-content>

                <!-- Main content -->
                <fo:flow flow-name="body">
                    <!-- Invoice prelude -->
                    <xsl:if test="abt:strip-space(/document/prelude) != ''">
                        <fo:block space-before="8mm" space-after="8mm" linefeed-treatment="preserve">
                            <xsl:value-of select="abt:strip-space(/document/prelude)" />
                        </fo:block>
                    </xsl:if>

                    <!-- Invoice line items table -->
                    <fo:block-container
                        border-before-style="solid" border-before-width="0.13mm" border-before-color="black"
                        border-after-style="solid" border-after-width="0.13mm" border-after-color="black"
                        space-before="5mm">
                        <fo:table table-layout="fixed" width="100%" padding="0mm" margin="0mm">
                            <fo:table-column column-width="8.5cm"/>
                            <fo:table-column column-width="1.5cm"/>
                            <fo:table-column column-width="2.0cm"/>
                            <fo:table-column column-width="1.5cm"/>
                            <fo:table-column column-width="2.25cm"/>
                            <fo:table-header>
                                <fo:table-row>
                                    <fo:table-cell padding-before="2mm" padding-after="2mm">
                                        <fo:block text-align="start" font-weight="600">Description</fo:block>
                                    </fo:table-cell>
                                    <fo:table-cell padding-before="2mm" padding-after="2mm">
                                        <fo:block text-align="end" font-weight="600">Qty</fo:block>
                                    </fo:table-cell>
                                    <fo:table-cell padding-before="2mm" padding-after="2mm">
                                        <fo:block text-align="end" font-weight="600">Rate</fo:block>
                                    </fo:table-cell>
                                    <fo:table-cell padding-before="2mm" padding-after="2mm">
                                        <fo:block text-align="end" font-weight="600">Tax</fo:block>
                                    </fo:table-cell>
                                    <fo:table-cell padding-before="2mm" padding-after="2mm">
                                        <fo:block text-align="end" font-weight="600">Amount</fo:block>
                                    </fo:table-cell>
                                </fo:table-row>
                            </fo:table-header>
                            <xsl:apply-templates select="/document/items" />
                        </fo:table>
                    </fo:block-container>

                    <!-- Invoice totals -->
                    <fo:block-container space-before="5mm">
                        <fo:table table-layout="fixed" width="100%" padding="0mm" margin="0mm">
                            <fo:table-column column-width="11cm"/>
                            <fo:table-column column-width="6.25cm"/>
                            <fo:table-body>
                                <fo:table-row>
                                    <fo:table-cell>
                                        <fo:block></fo:block>
                                    </fo:table-cell>
                                    <fo:table-cell>
                                        <fo:table table-layout="fixed" width="100%">
                                            <fo:table-column column-width="4cm"/>
                                            <fo:table-column column-width="2.25cm"/>
                                            <fo:table-body>
                                                <fo:table-row>
                                                    <fo:table-cell padding-before="1mm" padding-after="1mm">
                                                        <fo:block text-align="start">Sum Net:</fo:block>
                                                    </fo:table-cell>
                                                    <fo:table-cell padding-before="1mm" padding-after="1mm">
                                                        <fo:block text-align="end"><xsl:value-of select="abt:format-amount(/document/sums/net)" /></fo:block>
                                                    </fo:table-cell>
                                                </fo:table-row>
                                                <fo:table-row>
                                                    <fo:table-cell padding-before="1mm" padding-after="1mm">
                                                        <fo:block text-align="start" font-weight="600">Sum Total:</fo:block>
                                                    </fo:table-cell>
                                                    <fo:table-cell padding-before="1mm" padding-after="1mm">
                                                        <fo:block text-align="end" font-weight="600"><xsl:value-of select="abt:format-amount(/document/sums/total)" /></fo:block>
                                                    </fo:table-cell>
                                                </fo:table-row>
                                            </fo:table-body>
                                        </fo:table>
                                    </fo:table-cell>
                                </fo:table-row>
                            </fo:table-body>
                        </fo:table>
                    </fo:block-container>

                    <!-- Tax classes -->
                    <xsl:apply-templates select="/document/sums/tax-classes" />

                    <!-- Invoice-specific payment information -->
                    <xsl:if test="abt:strip-space(/document/payment-info) != ''">
                        <fo:block space-before="8mm" linefeed-treatment="preserve">
                            <xsl:value-of select="abt:strip-space(/document/payment-info)" />
                        </fo:block>
                    </xsl:if>
                </fo:flow>
            </fo:page-sequence>
        </fo:root>
    </xsl:template>

</xsl:stylesheet>