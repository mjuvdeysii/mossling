import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// On-device Vision foreground subject cutout engine creating cotton-paper die-cut stickers
/// completely offline (zero external APIs, zero extra camera permissions).
enum VisionSubjectCutout {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Segments the foreground food/object subject from `image` on-device and frames it with a crisp
    /// cotton-paper white die-cut border and gentle shadow. Always returns a valid sticker via rounded fallback.
    static func extractDieCutSticker(from image: UIImage, maxDimension: CGFloat = 512) async -> UIImage {
        let normalized = normalizeAndLimit(image, maxSide: 768)
        guard let cgInput = normalized.cgImage else {
            return makeFallbackRoundSticker(from: normalized, maxDimension: maxDimension)
        }

        let extracted: UIImage? = await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                let request = VNGenerateForegroundInstanceMaskRequest()
                let handler = VNImageRequestHandler(cgImage: cgInput, options: [:])
                do {
                    try handler.perform([request])
                    guard let observation = request.results?.first,
                          !observation.allInstances.isEmpty else {
                        return nil
                    }
                    let maskBuffer = try observation.generateScaledMaskForImage(
                        forInstances: observation.allInstances,
                        from: handler
                    )
                    let ciInput = CIImage(cgImage: cgInput)
                    let ciMask = CIImage(cvPixelBuffer: maskBuffer)
                    let blend = CIFilter.blendWithMask()
                    blend.inputImage = ciInput
                    blend.backgroundImage = CIImage(color: .clear).cropped(to: ciInput.extent)
                    blend.maskImage = ciMask
                    guard let outputCI = blend.outputImage,
                          let maskedCG = ciContext.createCGImage(outputCI, from: ciInput.extent) else {
                        return nil
                    }
                    let cropped = cropToNonTransparentBounds(maskedCG) ?? maskedCG
                    return renderDieCutSticker(cutoutCG: cropped, maxDimension: maxDimension)
                } catch {
                    return nil
                }
            }
        }.value

        return extracted ?? makeFallbackRoundSticker(from: normalized, maxDimension: maxDimension)
    }

    /// Synchronous deterministic circular die-cut fallback when Vision finds no distinct instance
    /// (for instance, flat soup/puree bowls or headless test environments).
    static func makeFallbackRoundSticker(from image: UIImage, maxDimension: CGFloat = 512) -> UIImage {
        let side = max(64, maxDimension)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let padding = side * 0.08
        let border = max(5, side * 0.036)
        let outerRect = CGRect(x: padding, y: padding, width: side - padding * 2, height: side - padding * 2)
        let innerRect = outerRect.insetBy(dx: border, dy: border)

        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { ctx in
            let gc = ctx.cgContext
            gc.saveGState()
            gc.setShadow(offset: CGSize(width: 0, height: side * 0.018), blur: side * 0.036, color: UIColor.black.withAlphaComponent(0.18).cgColor)
            UIColor(red: 1.0, green: 0.992, blue: 0.973, alpha: 1.0).setFill()
            UIBezierPath(ovalIn: outerRect).fill()
            gc.restoreGState()

            gc.saveGState()
            UIBezierPath(ovalIn: innerRect).addClip()
            drawAspectFill(image, in: innerRect)
            gc.restoreGState()
        }
    }

    private static func renderDieCutSticker(cutoutCG: CGImage, maxDimension: CGFloat) -> UIImage {
        let canvasSide = max(64, maxDimension)
        let margin: CGFloat = canvasSide * 0.12
        let drawBox = canvasSide - margin * 2
        let cw = CGFloat(cutoutCG.width)
        let ch = CGFloat(cutoutCG.height)
        guard cw > 1, ch > 1 else {
            return makeFallbackRoundSticker(from: UIImage(cgImage: cutoutCG), maxDimension: maxDimension)
        }

        let scale = min(drawBox / cw, drawBox / ch)
        let scaledW = cw * scale
        let scaledH = ch * scale
        let x = (canvasSide - scaledW) * 0.5
        let y = (canvasSide - scaledH) * 0.5

        let ciSubject = CIImage(cgImage: cutoutCG)
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: x, y: y))

        let extent = CGRect(x: 0, y: 0, width: canvasSide, height: canvasSide)
        let morph = CIFilter.morphologyMaximum()
        morph.inputImage = ciSubject
        morph.radius = Float(max(4, canvasSide * 0.022))

        var outlineCG: CGImage?
        if let dilated = morph.outputImage {
            let whiteConst = CIImage(color: CIColor(red: 1.0, green: 0.992, blue: 0.973, alpha: 1.0)).cropped(to: extent)
            let matte = CIFilter.blendWithAlphaMask()
            matte.inputImage = whiteConst
            matte.backgroundImage = CIImage(color: .clear).cropped(to: extent)
            matte.maskImage = dilated
            if let outlineCI = matte.outputImage {
                outlineCG = ciContext.createCGImage(outlineCI, from: extent)
            }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: CGSize(width: canvasSide, height: canvasSide), format: format).image { ctx in
            let gc = ctx.cgContext
            if let outlineCG {
                gc.saveGState()
                gc.setShadow(offset: CGSize(width: 0, height: canvasSide * 0.016), blur: canvasSide * 0.032, color: UIColor.black.withAlphaComponent(0.18).cgColor)
                UIImage(cgImage: outlineCG).draw(in: extent)
                gc.restoreGState()
            }
            UIImage(cgImage: cutoutCG).draw(in: CGRect(x: x, y: y, width: scaledW, height: scaledH))
        }
    }

    private static func cropToNonTransparentBounds(_ cgImage: CGImage) -> CGImage? {
        let w = cgImage.width
        let h = cgImage.height
        guard w > 0, h > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: &pixels,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: w * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        var minX = w, minY = h, maxX = -1, maxY = -1
        for row in 0..<h {
            let rowBase = row * w * 4
            for col in 0..<w where pixels[rowBase + col * 4 + 3] > 20 {
                if col < minX { minX = col }
                if col > maxX { maxX = col }
                if row < minY { minY = row }
                if row > maxY { maxY = row }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        return cgImage.cropping(to: cropRect)
    }

    private static func normalizeAndLimit(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let rawW = image.size.width * image.scale
        let rawH = image.size.height * image.scale
        let longest = max(rawW, rawH)
        let ratio = (longest > maxSide && longest > 0) ? (maxSide / longest) : 1.0
        let targetSize = CGSize(width: max(1, floor(rawW * ratio)), height: max(1, floor(rawH * ratio)))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private static func drawAspectFill(_ image: UIImage, in rect: CGRect) {
        let iw = max(1, image.size.width)
        let ih = max(1, image.size.height)
        let scale = max(rect.width / iw, rect.height / ih)
        let w = iw * scale
        let h = ih * scale
        image.draw(in: CGRect(x: rect.midX - w * 0.5, y: rect.midY - h * 0.5, width: w, height: h))
    }
}
