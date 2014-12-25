require 'builder'

class InvoiceRenderController

  def initialize(invoice, issuer)
    @invoice = invoice
    @issuer = issuer
  end

  def render
    customer_sales_tax_rates = @invoice.customer.sales_tax_rates
    puts customer_sales_tax_rates

    begin
      xml_file = Tempfile.new('abt')

      xml_file.path
      xml = Builder::XmlMarkup.new(:target=>xml_file, :indent => 2)
      xml.instruct! :xml, :encoding => 'UTF-8', :version => '1.0'

      xml.document :class => 'invoice' do |xml_invoice|
        xml_invoice.issuer do |xml_issuer|
          xml_issuer.address @issuer.name + "\n" + @issuer.address
          xml_issuer.tag! 'vatid', @issuer.vat_id
        end

        xml_invoice.recipient do |xml_recipient|
          xml_recipient.tag! 'order-no', @invoice.cust_order
          xml_recipient.reference @invoice.cust_reference

          xml_recipient.address @invoice.customer_name + "\n" + @invoice.customer_address
          xml_recipient.tag! 'account-no', @invoice.customer_account_number
          xml_recipient.tag! 'vatid', @invoice.customer_vat_id
          xml_recipient.tag! 'supplier-no', @invoice.customer_supplier_number
        end

        xml_invoice.currency 'EUR'
        xml_invoice.prelude @invoice.prelude
        xml_invoice.tag! 'tax-note', @invoice.tax_note
        xml_invoice.number @invoice.document_number
        xml_invoice.tag! 'issue-date', @invoice.date
        xml_invoice.tag! 'due-date', @invoice.due_date
        if @invoice.published
          if @invoice.token.nil?
            payment_url = ''
          else
            payment_url = Settings.payments.public_url.gsub('%token%', @invoice.token)
          end
        else
          payment_url = Settings.payments.public_url.gsub('%token%', 'NOT-YET-ASSIGNED')
        end

        xml_invoice.tag! 'payment-url', payment_url

        xml_invoice.items do |xml_items|
          @invoice.invoice_lines.each do |line|
            if line.type == 'text'
              xml_items.text do |xml_item|
                xml_item.title line.title
                xml_item.description line.description if line.description
              end
            elsif line.type == 'plain'
               xml_items.text do |xml_item|
                 xml_item.title line.title
                 xml_item.plain line.description if line.description
               end
            elsif line.type == 'subheading'
              xml_items.subheading do |xml_item|
                xml_item.title line.title
              end
            elsif line.type == 'item'
              xml_items.item do |xml_item|
                xml_item.title line.title
                xml_item.description line.description if line.description
                xml_item.quantity line.quantity
                xml_item.rate line.rate
                xml_item.amount line.amount
                xml_item.tag! 'tax-class', line.sales_tax_indicator_code
              end
            end
          end
        end

        puts @invoice.tax_classes.inspect
        puts "len: #{@invoice.tax_classes.length}"

        xml_invoice.sums do |xml_sums|
          if !@invoice.tax_classes.nil? and @invoice.tax_classes.length > 0
            xml_sums.tag! 'tax-classes' do |xml_tax_classes|
              @invoice.tax_classes.values.each do |tax_class|
                xml_tax_classes.tag! 'tax-class', {:name => tax_class[:name], 'indicator-code' => tax_class[:indicator_code]} do |xml_tax_class|
                  xml_tax_class.percentage tax_class[:rate]
                  xml_tax_class.sum tax_class[:net]
                  xml_tax_class.value tax_class[:value]
                end
              end
            end
          end
          xml_sums.net @invoice.sum_net
          xml_sums.total @invoice.sum_total
        end

      end
      xml_file.close

      puts File.read(xml_file.path)

      template_path = Rails.root.join('app', 'foptemplate')
      tpl_xsl = template_path.join('invoice.xsl')
      fop_conf = template_path.join('fop-example-conf.xml')

      begin
        pdffile = Tempfile.new('abt')
        pdffile.close

        fop_command = '' +
            "cd \"#{template_path}\" && " +
            'JAVA_OPTS=-Djavax.xml.transform.TransformerFactory=net.sf.saxon.TransformerFactoryImpl ' +
            "\"#{Settings.fop.binary_path}\" " +
            "-xml \"#{xml_file.path}\" -xsl \"#{tpl_xsl}\" -pdf \"#{pdffile.path}\" -c \"#{fop_conf}\""

        puts fop_command

        `#{fop_command}`

        return File.read(pdffile.path)
      ensure
        pdffile.close true
      end
    ensure
      xml_file.close true
    end
  end
end