import Foundation
import Darwin
import SpriteKit
final class RenderProbe {
    private var intervals:[Double]=[],costs:[Double]=[]
    private var last=0.0
    private(set) var frames=0
    func record(now:Double,workMS:Double){
        if last>0,now-last<0.5 {intervals.append((now-last)*1000)}
        last=now;costs.append(workMS);frames+=1
        if intervals.count>360 {intervals.removeFirst(60)};if costs.count>360 {costs.removeFirst(60)}
    }
    func reset(){intervals.removeAll(keepingCapacity:true);costs.removeAll(keepingCapacity:true);last=0;frames=0}
    var snapshot:[String:Any] {
        func p95(_ a:[Double])->Double {let sorted=a.sorted();return sorted.isEmpty ? 0:sorted[min(sorted.count-1,Int(Double(sorted.count-1)*0.95))]}
        let sum=intervals.reduce(0,+),live=ProcessInfo.processInfo.systemUptime-last<1.5
        return ["callbackFPS":live && sum>0 ? Double(intervals.count)*1000/sum:0,"p95IntervalMS":p95(intervals),"p95WorkMS":p95(costs),"frames":frames,"gpuMeasured":false,"measurement":"native draw/update callbacks; not presented GPU frames"]
    }
}
final class WinterScene:SKScene {
    let probe=RenderProbe()
    override func update(_ currentTime:TimeInterval){probe.record(now:ProcessInfo.processInfo.systemUptime,workMS:0)}
}
final class PerformanceMonitor {
    private var intervals: [Double]=[]
    private var start=ProcessInfo.processInfo.systemUptime
    private var cpuStart=0.0
    private var lastSample=0.0
    private var previousCPU=0.0
    private(set) var snapshot: [String:Any] = [:]
    private func cpu() -> Double { var usage=rusage(); getrusage(RUSAGE_SELF,&usage); return Double(usage.ru_utime.tv_sec+usage.ru_stime.tv_sec)+Double(usage.ru_utime.tv_usec+usage.ru_stime.tv_usec)/1e6 }
    init() { cpuStart=cpu() }
    func resetTiming() { intervals.removeAll(keepingCapacity:true) }
    func tick(dt: Double, now: Double, particles: Int, battery: Bool, targetFPS: Int, simulating: Bool) {
        if dt>0 && dt<1 { intervals.append(dt); if intervals.count>3600 { intervals.removeFirst(600) } }
        guard now-lastSample>1 else { return }
        let currentCPU=cpu(), sampleDuration=lastSample == 0 ? max(1,now-start) : now-lastSample
        let recentCPU=(currentCPU-(lastSample == 0 ? cpuStart : previousCPU))/sampleDuration*100
        previousCPU=currentCPU; lastSample=now
        let sorted=intervals.sorted(), mean=intervals.reduce(0,+)/Double(max(1,intervals.count))
        var info=mach_task_basic_info(); var count=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let result=withUnsafeMutablePointer(to:&info) { $0.withMemoryRebound(to:integer_t.self,capacity:Int(count)) { task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count) } }
        var vm=task_vm_info_data_t(); var vmCount=mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size)/4
        let vmResult=withUnsafeMutablePointer(to:&vm) { $0.withMemoryRebound(to:integer_t.self,capacity:Int(vmCount)) { task_info(mach_task_self_,task_flavor_t(TASK_VM_INFO),$0,&vmCount) } }
        snapshot=["simulationHz":simulating && mean>0 ? 1/mean : 0,"simulating":simulating,"p95FrameMS":sorted.isEmpty ? 0 : sorted[min(sorted.count-1,Int(Double(sorted.count)*0.95))]*1000,
                  "cpuPercentOneCore":recentCPU,"cpuAverageSinceLaunch":(currentCPU-cpuStart)/max(1,now-start)*100,"residentMB":result == KERN_SUCCESS ? Double(info.resident_size)/1048576 : 0,
                  "physicalFootprintMB":vmResult == KERN_SUCCESS ? Double(vm.phys_footprint)/1048576 : 0,"uptimeSeconds":now-start,"particles":particles,"battery":battery,"targetFPS":targetFPS,"gpuMeasured":false]
    }
}
