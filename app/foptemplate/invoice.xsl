<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:abt="http://deduktiva.com/Namespace/ABT/XSLT">
    <xsl:output method="xml" indent="yes"/>
    <xsl:strip-space elements="*" />
    <xsl:decimal-format name="european" decimal-separator=',' grouping-separator='.' />

    <xsl:function name="abt:strip-space">
        <xsl:param name="string" />
        <xsl:value-of select="replace($string, '^\s+|\s+$', '')" />
    </xsl:function>
    <xsl:function name="abt:format-amount">
        <xsl:param name="value" />
        <xsl:value-of select="format-number($value, '###.###,00', 'european')" />
    </xsl:function>

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
                <fo:block text-align="end"><xsl:value-of select="@name" /></fo:block>
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

    <xsl:template match="/">
        <fo:root>
    <fo:layout-master-set>
        <fo:simple-page-master master-name="first"
                               margin-left="2.25cm"
                               margin-top="1.5cm"
                               margin-right="1.5cm"
                               margin-bottom="2cm"
                               page-width="21cm"
                               page-height="29.7cm">
            <fo:region-body region-name="body" margin-top="8.9cm" margin-bottom="0cm" />
            <fo:region-before region-name="first-page-header" />
            <fo:region-after region-name="any-page-footer" />
        </fo:simple-page-master>

        <fo:simple-page-master master-name="rest"
                               margin-left="2.25cm"
                               margin-top="0.75cm"
                               margin-right="1.5cm"
                               margin-bottom="2cm"
                               page-width="21cm"
                               page-height="29.7cm">
            <fo:region-body region-name="body" margin-top="2cm" margin-bottom="3cm" />
            <fo:region-before region-name="rest-page-header" />
            <fo:region-after region-name="any-page-footer" />
        </fo:simple-page-master>

        <fo:page-sequence-master master-name="psmA">
          <fo:repeatable-page-master-alternatives>
            <fo:conditional-page-master-reference master-reference="first"
              page-position="first" />
            <fo:conditional-page-master-reference master-reference="rest"
              page-position="rest" />
            <!-- recommended fallback procedure -->
            <fo:conditional-page-master-reference master-reference="rest" />
          </fo:repeatable-page-master-alternatives>
        </fo:page-sequence-master>
    </fo:layout-master-set>

    <fo:page-sequence master-reference="psmA" id="document-sequence" font-family="OpenSans" font-weight="200" font-size="11pt" line-height="12pt">
        <fo:static-content flow-name="first-page-header">


            <!-- left column: addresses -->

            <fo:block-container height="3cm" width="12cm" top="0cm" left="0cm" position="absolute">
                <!-- note: can't have linefeed before first line -->
                <fo:block linefeed-treatment="preserve">
                    <xsl:value-of select="abt:strip-space(/document/issuer/address)" />
                </fo:block>
            </fo:block-container>

            <fo:block-container height="0.5cm" width="12cm" top="3cm" left="0cm" position="absolute" font-size="6pt">
                <!-- inline sender -->
                <fo:block color="#0000ff" font-weight="normal" font-family="sans-serif">
                    Returns to: <xsl:value-of select="replace(abt:strip-space(/document/issuer/address), '\n', ', ')" />
                </fo:block>
            </fo:block-container>

            <fo:block-container height="3cm" width="8.95cm" top="3.5cm" left="0cm" position="absolute">
                <!-- note: can't have linefeed before first line -->
                <fo:block linefeed-treatment="preserve">
                    <xsl:value-of select="abt:strip-space(/document/recipient/address)" />
                </fo:block>
            </fo:block-container>



            <!-- right column: logo, document type, date, stuff -->
            <fo:block-container top="0cm" left="8.75cm" position="absolute">

                <fo:block-container height="1cm" width="6cm" top="0cm" left="0cm" position="absolute">
                    <fo:block text-align="start" font-size="9pt" color="#0000ff">
                        <fo:block white-space-collapse="false">
                            www.example.com      hi@example.com
                        </fo:block>
                        <fo:block>
                            voice +43 xxx xxxxxx
                        </fo:block>
                    </fo:block>
                </fo:block-container>

                <fo:block-container height="1cm" width="8cm" top="2.8cm" position="absolute">
                    <fo:block text-align="start" font-size="23pt">
                        Invoice
                    </fo:block>
                </fo:block-container>

                <!-- first and second rows of info boxes -->
                <fo:block-container top="4.25cm" position="absolute">
                    <fo:block-container position="absolute" width="4.1cm" top="0cm" left="0cm">
                        <fo:block color="#0000ff">Invoice No</fo:block>
                        <fo:block><xsl:value-of select="/document/number" /></fo:block>
                    </fo:block-container>

                    <fo:block-container position="absolute" width="4.1cm" top="0cm" left="4.375cm">
                        <fo:block color="#0000ff">Date</fo:block>
                        <fo:block><xsl:value-of select="/document/issue-date" /></fo:block>
                    </fo:block-container>

                    <!-- 2nd row -->
                    <fo:block-container position="absolute" width="4.1cm" top="1.5cm" left="0cm">
                        <fo:block color="#0000ff">Your Reference</fo:block>
                        <fo:block><xsl:value-of select="/document/recipient/reference" /></fo:block>
                    </fo:block-container>

                    <fo:block-container position="absolute" width="4.1cm" top="1.5cm" left="4.375cm">
                        <fo:block color="#0000ff">Your Order No</fo:block>
                        <fo:block><xsl:value-of select="/document/recipient/order-no" /></fo:block>
                    </fo:block-container>
                </fo:block-container>
            </fo:block-container>

            <!-- full width line -->

            <fo:block-container top="7.3cm" position="absolute">
                <fo:block-container position="absolute" width="4.1cm" top="0cm" left="0cm">
                    <fo:block color="#0000ff">Account No</fo:block>
                    <fo:block><xsl:value-of select="/document/recipient/account-no" /></fo:block>
                </fo:block-container>

                <fo:block-container position="absolute" width="4.1cm" top="0cm" left="4.375cm">
                    <fo:block color="#0000ff">Our VAT ID</fo:block>
                    <fo:block><xsl:value-of select="/document/issuer/vatid" /></fo:block>
                </fo:block-container>

                <fo:block-container position="absolute" width="4.1cm" top="0cm" left="8.75cm">
                    <fo:block color="#0000ff">Supplier No</fo:block>
                    <fo:block><xsl:value-of select="/document/recipient/supplier-no" /></fo:block>
                </fo:block-container>

                <fo:block-container position="absolute" width="4.1cm" top="0cm" left="13.125cm" text-align="start">
                    <fo:block color="#0000ff">Your VAT ID</fo:block>
                    <fo:block><xsl:value-of select="/document/recipient/vatid" /></fo:block>
                </fo:block-container>

            </fo:block-container>

        </fo:static-content>

        <fo:static-content flow-name="rest-page-header">
            <!-- logo -->
            <fo:block-container height="1cm" width="6cm" top="0cm" position="absolute">
                <fo:block text-align="start" font-size="9pt" color="#0000ff">
                    Example GmbH
                </fo:block>
            </fo:block-container>

            <fo:block-container top="0cm" left="8.75cm" position="absolute">
                <fo:block text-align="start">
                    Invoice <xsl:value-of select="/document/number" />
                </fo:block>
            </fo:block-container>

            <fo:block-container top="0cm" right="0cm" text-align="end" position="absolute">
                <fo:block>
                    Page <fo:page-number/> of <fo:page-number-citation-last ref-id="document-sequence"/>
                </fo:block>
            </fo:block-container>
        </fo:static-content>

        <fo:static-content flow-name="any-page-footer">
            <fo:block-container>
                <!-- folding marks -->
                <fo:block-container width="0.5cm"
                                    top="9.6cm" left="0.8cm"
                                    position="fixed"
                                    overflow="visible"
                        color="black">
                    <fo:block>
                        <fo:leader leader-length.minimum="100%" leader-length.optimum="100%" leader-pattern="rule" rule-thickness="0.13mm"/>
                    </fo:block>
                </fo:block-container>

                <fo:block-container width="0.5cm"
                                    top="19.5cm" left="0.8cm"
                                    position="fixed"
                                    overflow="visible">
                    <fo:block>
                        <fo:leader leader-length.minimum="100%" leader-length.optimum="100%" leader-pattern="rule" rule-thickness="0.13mm"/>
                    </fo:block>
                </fo:block-container>
            </fo:block-container>


            <fo:block-container text-align="end">
                <fo:block>
                    Page <fo:page-number/> of <fo:page-number-citation-last ref-id="document-sequence"/>
                </fo:block>
            </fo:block-container>
        </fo:static-content>

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
                    <fo:table-row color="#0000ff">
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
            <fo:block-container
                    space-before="5mm"
                    >
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
                        height="2.1cm"
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
                    <fo:block>Remittance method:</fo:block>
                    <fo:block-container>
                        <fo:block-container left="0cm" top="0mm" width="7cm" position="absolute">
                            <fo:block>Bank: A bank, A place, A country</fo:block>
                            <fo:block>BIC: SWIFTCODE</fo:block>
                        </fo:block-container>
                        <fo:block-container left="8.75cm" top="0mm" width="7cm" position="absolute">
                            <fo:block>Account Name: Example GmbH</fo:block>
                            <fo:block>Account No: ATNNNNNNNNNNNNNNNNNN</fo:block>
                        </fo:block-container>
                    </fo:block-container>
                </fo:block-container>

                <fo:block space-before="5mm" padding="0.6mm" text-align="justify" font-size="8pt" line-height="10pt">
                    Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
                </fo:block>
            </fo:block-container>

        </fo:flow>
    </fo:page-sequence>
</fo:root>
</xsl:template>
</xsl:stylesheet>
