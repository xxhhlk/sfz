importScripts 'vendor/libheif.js'

heif = null


loadHeif = ->
    return heif if heif?
    heif = self.libheif locateFile: (name) -> 'vendor/' + name
    heif


pickPrimary = (images) ->
    for img in images
        return img if img.is_primary?() is true
    images[0]


self.onmessage = (e) ->
    {id, buffer} = e.data
    images = []

    try
        lib = loadHeif()
        decoder = new lib.HeifDecoder
        images = decoder.decode new Uint8Array buffer
        throw new Error '文件中没有可解码的图像' if not images.length

        image = pickPrimary images
        width = image.get_width()
        height = image.get_height()
        pixels = new Uint8ClampedArray width * height * 4

        ok = await new Promise (resolve) ->
            image.display {data: pixels, width: width, height: height}, (result) ->
                resolve result?

        throw new Error '图像解码失败' if not ok

        self.postMessage {id: id, ok: true, width: width, height: height, pixels: pixels}, [pixels.buffer]
    catch err
        message = if err? and err.message then err.message else String err
        self.postMessage {id: id, ok: false, message: message}
    finally
        img.free?() for img in images
