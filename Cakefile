{spawn} = require 'child_process'
fs = require 'fs'
path = require 'path'

print = console.log.bind console

vendorFiles =
    'libheif.js': 'libheif.js'
    'libheif.wasm': 'libheif.wasm'
    'LICENSE': 'LICENSE.libheif'

copyVendor = () ->
    src = path.join 'node_modules', 'libheif-js', 'libheif-wasm'
    dst = path.join 'public', 'vendor'

    unless fs.existsSync src
        print 'libheif-js is missing, run npm install first'
        process.exit 1

    fs.mkdirSync dst, recursive: true

    for name, target of vendorFiles
        fs.copyFileSync path.join(src, name), path.join(dst, target)
        print 'copied ' + path.join dst, target

build = () ->
    coffeePkg = path.dirname require.resolve 'coffeescript/package.json'
    coffeeBin = path.join coffeePkg, 'bin', 'coffee'
    coffee = spawn process.execPath, [coffeeBin, '-c', '-o', 'public', 'src']
    coffee.stderr.on 'data', (data) ->
        process.stderr.write data.toString()
    coffee.stdout.on 'data', (data) ->
        print data.toString()
    coffee.on 'exit', (code) ->
        if code != 0
            process.exit code
        copyVendor()

task 'build', 'Build ./public from src/', ->
    build()
