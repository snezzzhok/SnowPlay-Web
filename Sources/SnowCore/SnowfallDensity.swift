import Foundation
public enum SnowfallDensity {
    public static let maximumParticles=3600
    public static let effectReserve=80
    /// Intensity controls visible density, independently of battery frame-rate limits.
    public static func count(intensity: Double, area: Double, mode: WinterMode, limit: Int) -> Int {
        let level=clamp(intensity,0,1)
        let factor=clamp(area/(1440*900),0.6,1.5)
        let requested=Int(2400*pow(level,1.25)*factor)
        return min(maximumParticles,max(0,limit),mode == .focus ? min(50,requested):requested)
    }
}
