# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with this
# work for additional information regarding copyright ownership.  The ASF
# licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.

module Buildr #:nodoc:
  module IntellijIdea
    def self.new_document(value)
      REXML::Document.new(value, :attribute_quote => :quote)
    end

    # Abstract base class for IdeaModule and IdeaProject
    class IdeaFile
      DEFAULT_PREFIX = ''
      DEFAULT_SUFFIX = ''
      DEFAULT_LOCAL_REPOSITORY_ENV_OVERRIDE = 'MAVEN_REPOSITORY'

      attr_reader :buildr_project
      attr_writer :prefix
      attr_writer :suffix
      attr_writer :id
      attr_accessor :template
      attr_accessor :local_repository_env_override

      def initialize
        @local_repository_env_override = DEFAULT_LOCAL_REPOSITORY_ENV_OVERRIDE
      end

      def prefix
        @prefix ||= DEFAULT_PREFIX
      end

      def suffix
        @suffix ||= DEFAULT_SUFFIX
      end

      def filename
        buildr_project.path_to("#{name}.#{extension}")
      end

      def id
        @id ||= buildr_project.name.split(':').last
      end

      def add_component(name, attrs = {}, &xml)
        self.components << create_component(name, attrs, &xml)
      end

      def add_component_in_lambda(name, attrs = {}, &xml)
        self.components << lambda do
          create_component(name, attrs, &xml)
        end
      end

      def add_component_from_file(filename)
        self.components << lambda do
          raise "Unable to locate file #{filename} adding component to idea file" unless File.exist?(filename)
          Buildr::IntellijIdea.new_document(IO.read(filename)).root
        end
      end

      def add_component_from_artifact(artifact)
        self.components << lambda do
          a = Buildr.artifact(artifact)
          a.invoke
          Buildr::IntellijIdea.new_document(CGI.escapeHTML(IO.read(a.to_s))).root
        end
      end

      # IDEA can not handle text content with indents so need to removing indenting
      # Can not pass true as third argument as the ruby library seems broken
      def write(f)
        document.write(f, -1, false, true)
      end

      def name
        "#{prefix}#{self.id}#{suffix}"
      end

      protected

      def relative(path)
        ::Buildr::Util.relative_path(File.expand_path(path.to_s), self.base_directory)
      end

      def base_directory
        buildr_project.path_to
      end

      def resolve_path_from_base(path, base_variable)
        m2repo = Buildr::Repositories.instance.local
        if path.to_s.index(m2repo) == 0 && !self.local_repository_env_override.nil?
          return path.sub(m2repo, "$#{self.local_repository_env_override}$")
        else
          begin
            return "#{base_variable}/#{relative(path)}"
          rescue ArgumentError
            # ArgumentError happens on windows when self.base_directory and path are on different drives
            return path
          end
        end
      end

      def file_path(path)
        "file://#{resolve_path(path)}"
      end

      def create_component(name, attrs = {})
        target = StringIO.new
        Builder::XmlMarkup.new(:target => target, :indent => 2).component({ :name => name }.merge(attrs)) do |xml|
          yield xml if block_given?
        end
        Buildr::IntellijIdea.new_document(target.string).root
      end

      def components
        @components ||= []
      end

      def create_composite_component(name, attrs, components)
        return nil if components.empty?
        component = self.create_component(name, attrs)
        components.each do |element|
          element = element.call if element.is_a?(Proc)
          component.add_element element
        end
        component
      end

      def add_to_composite_component(components)
        components << lambda do
          target = StringIO.new
          yield Builder::XmlMarkup.new(:target => target, :indent => 2)
          Buildr::IntellijIdea.new_document(target.string).root
        end
      end

      def load_document(filename)
        Buildr::IntellijIdea.new_document(File.read(filename))
      end

      def document
        if File.exist?(self.filename)
          doc = load_document(self.filename)
        else
          doc = base_document
          inject_components(doc, self.initial_components)
        end
        if self.template
          template_doc = load_document(self.template)
          REXML::XPath.each(template_doc, '//component') do |element|
            inject_component(doc, element)
          end
        end
        inject_components(doc, self.default_components.compact + self.components)

        # Sort the components in the same order the idea sorts them
        sorted = doc.root.get_elements('//component').sort { |s1, s2| s1.attribute('name').value <=> s2.attribute('name').value }
        doc = base_document
        sorted.each do |element|
          doc.root.add_element element
        end

        doc
      end

      def inject_components(doc, components)
        components.each do |component|
          # execute deferred components
          component = component.call if Proc === component
          inject_component(doc, component) if component
        end
      end

      # replace overridden component (if any) with specified component
      def inject_component(doc, component)
        doc.root.delete_element("//component[@name='#{component.attributes['name']}']")
        doc.root.add_element component
      end
    end

    # IdeaModule represents an .iml file
    class IdeaModule < IdeaFile
      DEFAULT_TYPE = 'JAVA_MODULE'

      attr_accessor :type
      attr_accessor :group
      attr_reader :facets
      attr_writer :jdk_version

      def initialize
        super()
        @type = DEFAULT_TYPE
      end

      def buildr_project=(buildr_project)
        @id = nil
        @facets = []
        @skip_content = false
        @buildr_project = buildr_project
      end

      def jdk_version
        @jdk_version || buildr_project.compile.options.source || '1.7'
      end

      def extension
        'iml'
      end

      def annotation_paths
        @annotation_paths ||= [buildr_project._(:source, :main, :annotations)].select { |p| File.exist?(p) }
      end

      def main_source_directories
        @main_source_directories ||= [buildr_project.compile.sources].flatten.compact
      end

      def main_resource_directories
        @main_resource_directories ||= [buildr_project.resources.sources].flatten.compact
      end

      def main_generated_source_directories
        @main_generated_source_directories ||= []
      end

      def main_generated_resource_directories
        @main_generated_resource_directories ||= []
      end

      def test_source_directories
        @test_source_directories ||= [buildr_project.test.compile.sources].flatten.compact
      end

      def test_resource_directories
        @test_resource_directories ||= [buildr_project.test.resources.sources].flatten.compact
      end

      def test_generated_source_directories
        @test_generated_source_directories ||= []
      end

      def test_generated_resource_directories
        @test_generated_resource_directories ||= []
      end

      def excluded_directories
        @excluded_directories ||= [
          buildr_project.resources.target,
          buildr_project.test.resources.target,
          buildr_project.path_to(:target, :main),
          buildr_project.path_to(:target, :test),
          buildr_project.path_to(:reports)
        ].flatten.compact
      end

      attr_writer :main_output_dir

      def main_output_dir
        @main_output_dir ||= buildr_project._(:target, :main, :idea, :classes)
      end

      attr_writer :test_output_dir

      def test_output_dir
        @test_output_dir ||= buildr_project._(:target, :test, :idea, :classes)
      end

      def main_dependencies
        @main_dependencies ||= buildr_project.compile.dependencies.dup
      end

      def test_dependencies
        @test_dependencies ||= buildr_project.test.compile.dependencies.dup
      end

      def add_facet(name, type)
        add_to_composite_component(self.facets) do |xml|
          xml.facet(:name => name, :type => type) do |xml|
            yield xml if block_given?
          end
        end
      end

      def skip_content?
        !!@skip_content
      end

      def skip_content!
        @skip_content = true
      end

      def add_gwt_facet(modules = {}, options = {})
        name = options[:name] || 'GWT'
        detected_gwt_version = nil
        if options[:gwt_dev_artifact]
          a = Buildr.artifact(options[:gwt_dev_artifact])
          a.invoke
          detected_gwt_version = a.to_s
        end

        settings =
          {
            :webFacet => 'Web',
            :compilerMaxHeapSize => '512',
            :compilerParameters => '-draftCompile -localWorkers 2 -strict',
            :gwtScriptOutputStyle => 'PRETTY'
          }.merge(options[:settings] || {})

        buildr_project.compile.dependencies.each do |d|
          if d.to_s =~ /\/com\/google\/gwt\/gwt-dev\/(.*)\//
            detected_gwt_version = d.to_s
            break
          end
        end unless detected_gwt_version

        if detected_gwt_version
          settings[:gwtSdkUrl] = resolve_path(File.dirname(detected_gwt_version))
          settings[:gwtSdkType] = 'maven'
        else
          settings[:gwtSdkUrl] = 'file://$GWT_TOOLS$'
        end

        add_facet(name, 'gwt') do |f|
          f.configuration do |c|
            settings.each_pair do |k, v|
              c.setting :name => k.to_s, :value => v.to_s
            end
            c.packaging do |d|
              modules.each_pair do |k, v|
                d.module :name => k, :enabled => v
              end
            end
          end
        end
      end

      def add_web_facet(options = {})
        name = options[:name] || 'Web'
        default_webroots = {}
        default_webroots[buildr_project._(:source, :main, :webapp)] = '/' if File.exist?(buildr_project._(:source, :main, :webapp))
        buildr_project.assets.paths.each { |p| default_webroots[p] = '/' }
        webroots = options[:webroots] || default_webroots
        default_deployment_descriptors = []
        %w(web.xml sun-web.xml glassfish-web.xml jetty-web.xml geronimo-web.xml context.xml weblogic.xml jboss-deployment-structure.xml jboss-web.xml ibm-web-bnd.xml ibm-web-ext.xml ibm-web-ext-pme.xml).
          each do |descriptor|
          webroots.each_pair do |path, relative_url|
            next unless relative_url == '/'
            d = "#{path}/WEB-INF/#{descriptor}"
            default_deployment_descriptors << d if File.exist?(d)
          end
        end
        deployment_descriptors = options[:deployment_descriptors] || default_deployment_descriptors

        add_facet(name, 'web') do |f|
          f.configuration do |c|
            c.descriptors do |d|
              deployment_descriptors.each do |deployment_descriptor|
                d.deploymentDescriptor :name => File.basename(deployment_descriptor), :url => file_path(deployment_descriptor)
              end
            end
            c.webroots do |w|
              webroots.each_pair do |webroot, relative_url|
                w.root :url => file_path(webroot), :relative => relative_url
              end
            end
          end
        end
      end

      def add_jpa_facet(options = {})
        name = options[:name] || 'JPA'

        source_roots = [buildr_project.iml.main_source_directories, buildr_project.compile.sources, buildr_project.resources.sources].flatten.compact
        default_deployment_descriptors = []
        %w[orm.xml persistence.xml].
          each do |descriptor|
          source_roots.each do |path|
            d = "#{path}/META-INF/#{descriptor}"
            default_deployment_descriptors << d if File.exist?(d)
          end
        end
        deployment_descriptors = options[:deployment_descriptors] || default_deployment_descriptors

        factory_entry = options[:factory_entry] || buildr_project.name.to_s
        validation_enabled = options[:validation_enabled].nil? ? true : options[:validation_enabled]
        if options[:provider_enabled]
          provider = options[:provider_enabled]
        else
          provider = nil
          { 'org.hibernate.ejb.HibernatePersistence' => 'Hibernate',
            'org.eclipse.persistence.jpa.PersistenceProvider' => 'EclipseLink' }.
            each_pair do |match, candidate_provider|
            deployment_descriptors.each do |descriptor|
              if File.exist?(descriptor) && /#{Regexp.escape(match)}/ =~ IO.read(descriptor)
                provider = candidate_provider
              end
            end
          end
        end

        add_facet(name, 'jpa') do |f|
          f.configuration do |c|
            if provider
              c.setting :name => 'validation-enabled', :value => validation_enabled
              c.setting :name => 'provider-name', :value => provider
            end
            c.tag!('datasource-mapping') do |ds|
              ds.tag!('factory-entry', :name => factory_entry)
            end
            deployment_descriptors.each do |descriptor|
              c.deploymentDescriptor :name => File.basename(descriptor), :url => file_path(descriptor)
            end
          end
        end
      end

      protected

      def main_dependency_details
        target_dir = buildr_project.compile.target.to_s
        main_dependencies.select { |d| d.to_s != target_dir }.collect do |d|
          dependency_path = d.to_s
          export = true
          source_path = nil
          annotations_path = nil
          if d.is_a?(Buildr::Artifact)
            source_spec = d.to_spec_hash.merge(:classifier => 'sources')
            source_path = Buildr.artifact(source_spec).to_s
            source_path = nil unless File.exist?(source_path)
          end
          if d.is_a?(Buildr::Artifact)
            annotations_spec = d.to_spec_hash.merge(:classifier => 'annotations')
            annotations_path = Buildr.artifact(annotations_spec).to_s
            annotations_path = nil unless File.exist?(annotations_path)
          end
          [dependency_path, export, source_path, annotations_path]
        end
      end

      def test_dependency_details
        main_dependencies_paths = main_dependencies.map(&:to_s)
        target_dir = buildr_project.compile.target.to_s
        test_dependencies.select { |d| d.to_s != target_dir }.collect do |d|
          dependency_path = d.to_s
          export = main_dependencies_paths.include?(dependency_path)
          source_path = nil
          annotations_path = nil
          if d.is_a?(Buildr::Artifact)
            source_spec = d.to_spec_hash.merge(:classifier => 'sources')
            source_path = Buildr.artifact(source_spec).to_s
            source_path = nil unless File.exist?(source_path)
          end
          if d.is_a?(Buildr::Artifact)
            annotations_spec = d.to_spec_hash.merge(:classifier => 'annotations')
            annotations_path = Buildr.artifact(annotations_spec).to_s
            annotations_path = nil unless File.exist?(annotations_path)
          end
          [dependency_path, export, source_path, annotations_path]
        end
      end

      def base_document
        target = StringIO.new
        Builder::XmlMarkup.new(:target => target).module(:version => '4', :relativePaths => 'true', :type => self.type)
        Buildr::IntellijIdea.new_document(target.string)
      end

      def initial_components
        []
      end

      def default_components
        [
          lambda { module_root_component },
          lambda { facet_component }
        ]
      end

      def facet_component
        create_composite_component('FacetManager', {}, self.facets)
      end

      def module_root_component
        options = { 'inherit-compiler-output' => 'false' }
        options['LANGUAGE_LEVEL'] = "JDK_#{jdk_version.gsub(/\./, '_')}" unless jdk_version == buildr_project.root_project.compile.options.source
        create_component('NewModuleRootManager', options) do |xml|
          generate_compile_output(xml)
          generate_content(xml) unless skip_content?
          generate_initial_order_entries(xml)
          project_dependencies = []

          # If a project dependency occurs as a main dependency then add it to the list
          # that are excluded from list of test modules
          self.main_dependency_details.each do |dependency_path, export, source_path|
            next unless export
            project_for_dependency = Buildr.projects.detect do |project|
              [project.packages, project.compile.target, project.resources.target, project.test.compile.target, project.test.resources.target].flatten.
                detect { |artifact| artifact.to_s == dependency_path }
            end
            project_dependencies << project_for_dependency if project_for_dependency
          end

          main_project_dependencies = project_dependencies.dup
          self.test_dependency_details.each do |dependency_path, export, source_path, annotations_path|
            next if export
            generate_lib(xml, dependency_path, export, source_path, annotations_path, project_dependencies)
          end

          test_project_dependencies = project_dependencies - main_project_dependencies
          self.main_dependency_details.each do |dependency_path, export, source_path, annotations_path|
            next unless export
            generate_lib(xml, dependency_path, export, source_path, annotations_path, test_project_dependencies)
          end

          xml.orderEntryProperties
        end
      end

      def generate_lib(xml, dependency_path, export, source_path, annotations_path, project_dependencies)
        project_for_dependency = Buildr.projects.detect do |project|
          [project.packages, project.compile.target, project.resources.target, project.test.compile.target, project.test.resources.target].flatten.
            detect { |artifact| artifact.to_s == dependency_path }
        end
        if project_for_dependency
          if project_for_dependency.iml? &&
            !project_dependencies.include?(project_for_dependency) &&
            project_for_dependency != self.buildr_project
            generate_project_dependency(xml, project_for_dependency.iml.name, export, !export)
          end
          project_dependencies << project_for_dependency
        else
          generate_module_lib(xml, url_for_path(dependency_path), export, (source_path ? url_for_path(source_path) : nil), (annotations_path ? url_for_path(annotations_path) : nil), !export)
        end
      end

      def jar_path(path)
        "jar://#{resolve_path(path)}!/"
      end

      def url_for_path(path)
        if path =~ /jar$/i
          jar_path(path)
        else
          file_path(path)
        end
      end

      def resolve_path(path)
        resolve_path_from_base(path, '$MODULE_DIR$')
      end

      def generate_compile_output(xml)
        xml.output(:url => file_path(self.main_output_dir.to_s))
        xml.tag!('output-test', :url => file_path(self.test_output_dir.to_s))
        xml.tag!('exclude-output')
        paths = self.annotation_paths
        unless paths.empty?
          xml.tag!('annotation-paths') do |xml|
            paths.each do |path|
              xml.root(:url => file_path(path))
            end
          end
        end
      end

      def generate_content(xml)
        xml.content(:url => 'file://$MODULE_DIR$') do
          # Source folders
          [
            { :dirs => (self.main_source_directories.dup - self.main_generated_source_directories) },
            { :dirs => self.main_generated_source_directories, :generated => true },
            { :type => 'resource', :dirs => (self.main_resource_directories.dup - self.main_generated_resource_directories) },
            { :type => 'resource', :dirs => self.main_generated_resource_directories, :generated => true },
            { :test => true, :dirs => (self.test_source_directories - self.test_generated_source_directories) },
            { :test => true, :dirs => self.test_generated_source_directories, :generated => true },
            { :test => true, :type => 'resource', :dirs => (self.test_resource_directories - self.test_generated_resource_directories) },
            { :test => true, :type => 'resource', :dirs => self.test_generated_resource_directories, :generated => true },
          ].each do |content|
            content[:dirs].map { |dir| dir.to_s }.compact.sort.uniq.each do |dir|
              options = {}
              options[:url] = file_path(dir)
              options[:isTestSource] = (content[:test] ? 'true' : 'false') if content[:type] != 'resource'
              options[:type] = 'java-resource' if content[:type] == 'resource' && !content[:test]
              options[:type] = 'java-test-resource' if content[:type] == 'resource' && content[:test]
              options[:generated] = 'true' if content[:generated]
              xml.sourceFolder options
            end
          end

          # Exclude target directories
          self.net_excluded_directories.
            collect { |dir| file_path(dir) }.
            select { |dir| relative_dir_inside_dir?(dir) }.
            sort.each do |dir|
            xml.excludeFolder :url => dir
          end
        end
      end

      def relative_dir_inside_dir?(dir)
        !dir.include?('../')
      end

      def generate_initial_order_entries(xml)
        xml.orderEntry :type => 'sourceFolder', :forTests => 'false'
        xml.orderEntry :type => 'jdk', :jdkName => jdk_version, :jdkType => 'JavaSDK'
      end

      def generate_project_dependency(xml, other_project, export, test = false)
        attribs = { :type => 'module', 'module-name' => other_project }
        attribs[:exported] = '' if export
        attribs[:scope] = 'TEST' if test
        xml.orderEntry attribs
      end

      def generate_module_lib(xml, path, export, source_path, annotations_path, test = false)
        attribs = { :type => 'module-library' }
        attribs[:exported] = '' if export
        attribs[:scope] = 'TEST' if test
        xml.orderEntry attribs do
          xml.library do
            xml.ANNOTATIONS do
              xml.root :url => annotations_path
            end if annotations_path
            xml.CLASSES do
              xml.root :url => path
            end
            xml.JAVADOC
            xml.SOURCES do
              if source_path
                xml.root :url => source_path
              end
            end
          end
        end
      end

      # Don't exclude things that are subdirectories of other excluded things
      def net_excluded_directories
        net = []
        all = self.excluded_directories.map { |dir| buildr_project._(dir.to_s) }.sort_by { |d| d.size }
        all.each_with_index do |dir, i|
          unless all[0...i].find { |other| dir =~ /^#{other}/ }
            net << dir
          end
        end
        net
      end
    end

    module ProjectExtension
      include Extension

      first_time do
        desc 'Generate Intellij IDEA artifacts for all projects'
        Project.local_task 'idea' => 'artifacts'

        desc 'Delete the generated Intellij IDEA artifacts'
        Project.local_task 'idea:clean'
      end

      before_define do |project|
        project.recursive_task('idea')
        project.recursive_task('idea:clean')
      end

      after_define do |project|
        idea = project.task('idea')

        files = [(project.iml if project.iml?)].compact

        files.each do |ideafile|
          module_dir = File.dirname(ideafile.filename)
          idea.enhance do |task|
            mkdir_p module_dir
            info "Writing #{ideafile.filename}"
            t = Tempfile.open('buildr-idea')
            temp_filename = t.path
            t.close!
            File.open(temp_filename, 'w') do |f|
              ideafile.write f
            end
            mv temp_filename, ideafile.filename
          end
        end

        project.task('idea:clean') do
          files.each do |f|
            info "Removing #{f.filename}" if File.exist?(f.filename)
            rm_rf f.filename
          end
        end
      end

      def iml
        if iml?
          unless @iml
            inheritable_iml_source = self.parent
            while inheritable_iml_source && !inheritable_iml_source.iml?
              inheritable_iml_source = inheritable_iml_source.parent;
            end
            @iml = inheritable_iml_source ? inheritable_iml_source.iml.clone : IdeaModule.new
            @iml.buildr_project = self
          end
          return @iml
        else
          raise "IML generation is disabled for #{self.name}"
        end
      end

      def no_iml
        @has_iml = false
      end

      def iml?
        @has_iml = @has_iml.nil? ? true : @has_iml
      end
    end
  end
end

class Buildr::Project
  include Buildr::IntellijIdea::ProjectExtension
end
