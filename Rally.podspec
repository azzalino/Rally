
Pod::Spec.new do |s|
  s.name         = "Rally"
  s.version      = "1.0.0"
  s.summary      = "Summary goes here."

  s.description  = <<-DESC
                   
                   Description goes here
                                       
                   DESC

   s.homepage     = "http://www.rallypwr.com"
   s.license   =  'MIT'
   
   s.author             = { "Cory Azzalino" => "cory.azzalino@gmail.com" }
   s.ios.deployment_target = '7.0'
   s.source       = { :git => "https://github.com/azzalino/Rally.git", :tag => "1.0.0" }
   s.source_files  = '*.{h,m}'
   s.requires_arc = true
end
