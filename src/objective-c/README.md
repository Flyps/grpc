[![Cocoapods](https://img.shields.io/cocoapods/v/gRPC.svg)](https://cocoapods.org/pods/gRPC)
# gRPC for Objective-C

- [Write your API declaration in proto format](#write-protos)
- [Integrate a proto library in your project](#cocoapods)
- [Use the generated library in your code](#use)
- [Use gRPC without Protobuf](#no-proto)
- [Alternatives to the steps above](#alternatives)
    - [Install protoc with the gRPC plugin](#install)
    - [Install protoc and the gRPC plugin without using Homebrew](#no-homebrew)
    - [Integrate the generated gRPC library without using Cocoapods](#no-cocoapods)

While gRPC doesn't require the use of an IDL to describe the API of services, using one simplifies
usage and adds some interoperability guarantees. Here we use [Protocol Buffers][], and provide a
plugin for the Protobuf Compiler (_protoc_) to generate client libraries to communicate with gRPC
services.

<a name="write-protos"></a>
## Write your API declaration in proto format

For this you can consult the [Protocol Buffers][]' official documentation, or learn from a quick
example [here](https://github.com/grpc/grpc/tree/master/examples#defining-a-service).

<a name="cocoapods"></a>
## Integrate a proto library in your project

Install [Cocoapods](https://cocoapods.org/#install).

You need to create a Podspec file for your proto library. You may simply copy the following example
to the directory where your `.proto` files are located, updating the name, version and license as
necessary. You also need to set the `pods_root` variable to the correct value, depending on where
you place this podspec relative to your Podfile.

```ruby
Pod::Spec.new do |s|
  s.name     = '<Podspec file name>'
  s.version  = '0.0.1'
  s.license  = '...'
  s.authors  = { '<your name>' => '<your email>' }
  s.homepage = '...'
  s.summary = '...'
  s.source = { :git => 'https://github.com/...' }

  s.ios.deployment_target = '7.1'
  s.osx.deployment_target = '10.9'

  # Base directory where the .proto files are.
  src = '.'

  # We'll use protoc with the gRPC plugin.
  s.dependency '!ProtoCompiler-gRPCPlugin', '~> 1.0.0-pre1'

  # Pods directory corresponding to this app's Podfile, relative to the location of this podspec.
  pods_root = '<path to your Podfile>/Pods'

  # Path where Cocoapods downloads protoc and the gRPC plugin.
  protoc_dir = "#{pods_root}/!ProtoCompiler"
  protoc = "#{protoc_dir}/protoc"
  plugin = "#{pods_root}/!ProtoCompiler-gRPCPlugin/grpc_objective_c_plugin"

  # Directory where you want the generated files to be placed. This is an example.
  dir = "#{pods_root}/#{s.name}"

  # Run protoc with the Objective-C and gRPC plugins to generate protocol messages and gRPC clients.
  # You can run this command manually if you later change your protos and need to regenerate.
  # Alternatively, you can advance the version of this podspec and run `pod update`.
  s.prepare_command = <<-CMD
    mkdir -p #{dir}
    #{protoc} \
        --plugin=protoc-gen-grpc=#{plugin} \
        --objc_out=#{dir} \
        --grpc_out=#{dir} \
        -I #{src} \
        -I #{protoc_dir} \
        #{src}/*.proto
  CMD

  # The --objc_out plugin generates a pair of .pbobjc.h/.pbobjc.m files for each .proto file.
  s.subspec 'Messages' do |ms|
    ms.source_files = "#{dir}/*.pbobjc.{h,m}"
    ms.header_mappings_dir = dir
    ms.requires_arc = false
    # The generated files depend on the protobuf runtime.
    ms.dependency 'Protobuf'
    # This is needed by all pods that depend on Protobuf:
    ms.pod_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1',
    }
  end

  # The --objcgrpc_out plugin generates a pair of .pbrpc.h/.pbrpc.m files for each .proto file with
  # a service defined.
  s.subspec 'Services' do |ss|
    ss.source_files = "#{dir}/*.pbrpc.{h,m}"
    ss.header_mappings_dir = dir
    ss.requires_arc = true
    # The generated files depend on the gRPC runtime, and on the files generated by `--objc_out`.
    ss.dependency 'gRPC-ProtoRPC'
    ss.dependency "#{s.name}/Messages"
  end
end
```

The file should be named `<Podspec file name>.podspec`.

Note: If your proto files are in a directory hierarchy, you might want to adjust the _globs_ used in
the sample Podspec above. For example, you could use:

```ruby
  s.prepare_command = <<-CMD
    ...
        #{src}/*.proto #{src}/**/*.proto
  CMD
  ...
    ms.source_files = "#{dir}/*.pbobjc.{h,m}", "#{dir}/**/*.pbobjc.{h,m}"
  ...
    ss.source_files = "#{dir}/*.pbrpc.{h,m}", "#{dir}/**/*.pbrpc.{h,m}"
```

Once your library has a Podspec, Cocoapods can install it into any XCode project. For that, go into
your project's directory and create a Podfile by running:

```sh
pod init
```

Next add a line to your Podfile to refer to your library's Podspec. Use `:path` as described
[here](https://guides.cocoapods.org/using/the-podfile.html#using-the-files-from-a-folder-local-to-the-machine):

```ruby
pod '<Podspec file name>', :path => 'path/to/the/directory/of/your/podspec'
```

You can look at this [example Podfile][].

Finally, in your project's directory, run:

```sh
pod install
```

<a name="use"></a>
## Use the generated library in your code

Please check the [example apps][] for examples of how to use a generated gRPC library.

<a name="no-proto"></a>
## Use gRPC without Protobuf

This [tests file](https://github.com/grpc/grpc/tree/master/src/objective-c/tests/GRPCClientTests.m)
shows how to use the generic gRPC Objective-C client without generated protobuf files.

<a name="alternatives"></a>
## Alternatives to the steps above

<a name="install"></a>
### Install _protoc_ with the gRPC plugin

Although it's not recommended (because it can lead to hard-to-solve version conflicts), it is
sometimes more convenient to install _protoc_ and the gRPC plugin in your development machine,
instead of letting Cocoapods download the appropriate versions for you. To do so, on Mac OS X or
later, install [homebrew][].

The run the following command to install _protoc_ and the gRPC _protoc_ plugin:
```sh
$ curl -fsSL https://goo.gl/getgrpc | bash -
```
This will download and run the [gRPC install script][].

<a name="no-homebrew"></a>
### Install _protoc_ and the gRPC plugin without using Homebrew

First install v3 of the Protocol Buffers compiler (_protoc_), by cloning
[its Git repository](https://github.com/google/protobuf) and following these
[installation instructions](https://github.com/google/protobuf#c-installation---unix)
(the ones titled C++; don't miss the note for Mac users).

Then clone this repository and execute the following commands from the root directory where it was
cloned.

Compile the gRPC plugins for _protoc_:
```sh
make grpc_objective_c_plugin
```

Create a symbolic link to the compiled plugin binary somewhere in your `$PATH`:
```sh
ln -s `pwd`/bins/opt/grpc_objective_c_plugin /usr/local/bin/protoc-gen-objcgrpc
```
(Notice that the name of the created link must begin with "`protoc-gen-`" for _protoc_ to recognize
it as a plugin).

If you don't want to create the symbolic link, you can alternatively copy the binary (with the
appropriate name). Or you might prefer instead to specify the plugin's path as a flag when invoking
_protoc_, in which case no system modification nor renaming is necessary.

<a name="no-cocoapods"></a>
### Integrate the generated gRPC library without using Cocoapods

You need to compile the generated `.pbobjc.*` files (the enums and messages) without ARC support,
and the generated `.pbrpc.*` files (the services) with ARC support. The generated code depends on
v0.12+ of the Objective-C gRPC runtime library and v3.0.0-alpha-4+ of the Objective-C Protobuf
runtime library.

These libraries need to be integrated into your project as described in their respective Podspec
files:

* [Podspec](https://github.com/grpc/grpc/blob/master/gRPC.podspec) for the Objective-C gRPC runtime
library. This can be tedious to configure manually.
* [Podspec](https://github.com/google/protobuf/blob/master/Protobuf.podspec) for the
Objective-C Protobuf runtime library.

[Protocol Buffers]:https://developers.google.com/protocol-buffers/
[homebrew]:http://brew.sh
[gRPC install script]:https://raw.githubusercontent.com/grpc/homebrew-grpc/master/scripts/install
[example Podfile]:https://github.com/grpc/grpc/blob/master/examples/objective-c/helloworld/Podfile
[example apps]: https://github.com/grpc/grpc/tree/master/examples/objective-c