# fop1.1 + plugins, dependencies
class abt::fop {
  package { 'openjdk-7-jre-headless':
    ensure => installed,
  }
  file { '/usr/local/bin/fop':
    source => 'puppet:///modules/abt/fop/fop',
    mode => 0755,
  }

  file { '/usr/local/fop':
    ensure => directory,
    mode => 0644,
  }
  file { '/usr/local/fop/fontbox-1.3.1.jar':
    source => 'puppet:///modules/abt/fop/fontbox-1.3.1.jar',
    mode => 0644,
  }
  file { '/usr/local/fop/pdfbox-1.3.1.jar':
    source => 'puppet:///modules/abt/fop/pdfbox-1.3.1.jar',
    mode => 0644,
  }
  file { '/usr/local/fop/jempbox-1.3.1.jar':
    source => 'puppet:///modules/abt/fop/jempbox-1.3.1.jar',
    mode => 0644,
  }
  file { '/usr/local/fop/commons-io-1.3.1.jar':
    source => 'puppet:///modules/abt/fop/commons-io-1.3.1.jar',
    mode => 0644,
  }
  file { '/usr/local/fop/avalon-framework-4.2.0.jar':
    source => 'puppet:///modules/abt/fop/avalon-framework-4.2.0.jar',
    mode => 0644,
  }
  file { '/usr/local/fop/batik-all-1.7.jar':
    source => 'puppet:///modules/abt/fop/batik-all-1.7.jar',
    mode => 0644,
  }
  file { '/usr/local/fop/commons-logging-1.0.4.jar':
    source => 'puppet:///modules/abt/fop/commons-logging-1.0.4.jar',
    mode => 0644,
  }
  file { '/usr/local/fop/serializer-2.7.0.jar':
    source => 'puppet:///modules/abt/fop/serializer-2.7.0.jar',
    mode => 0644,
  }
  file { '/usr/local/fop/xalan-2.7.0.jar':
    source => 'puppet:///modules/abt/fop/xalan-2.7.0.jar',
    mode => 0644,
  }
  file { '/usr/local/fop/xercesImpl-2.7.1.jar':
    source => 'puppet:///modules/abt/fop/xercesImpl-2.7.1.jar',
    mode => 0644,
  }
  file { '/usr/local/fop/xml-apis-1.3.04.jar':
    source => 'puppet:///modules/abt/fop/xml-apis-1.3.04.jar',
    mode => 0644,
  }
  file { '/usr/local/fop/xml-apis-ext-1.3.04.jar':
    source => 'puppet:///modules/abt/fop/xml-apis-ext-1.3.04.jar',
    mode => 0644,
  }
  file { '/usr/local/fop/xmlgraphics-commons-1.5.jar':
    source => 'puppet:///modules/abt/fop/xmlgraphics-commons-1.5.jar',
    mode => 0644,
  }
  file { '/usr/local/fop/fop.jar':
    source => 'puppet:///modules/abt/fop/fop.jar',
    mode => 0644,
  }
  file { '/usr/local/fop/fop-pdf-images-2.1.0.SNAPSHOT.jar':
    source => 'puppet:///modules/abt/fop/fop-pdf-images-2.1.0.SNAPSHOT.jar',
    mode => 0644,
  }
  file { '/usr/local/fop/saxon9he.jar':
    source => 'puppet:///modules/abt/fop/saxon9he.jar',
    mode => 0644,
  }
}
