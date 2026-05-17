@[Link("glib-2.0")]
lib LibGLib
  type GArray = Void

  struct GArrayStruct
    data : UInt8*
    len : LibC::UInt
  end

  fun g_array_new(zero_terminated : LibC::Int, clear_ : LibC::Int, element_size : LibC::UInt) : GArrayStruct*
  fun g_array_free(array : GArrayStruct*, free_segment : LibC::Int) : UInt8*
  fun g_free(ptr : Void*) : Void
end
