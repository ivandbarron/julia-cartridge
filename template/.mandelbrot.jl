function juliaset(z::Complex, z0::Complex, nmax::Int)
  for n = 1:nmax
    if abs(z) > 2
      return uint8(n-1)
    end
    z = z^2 + z0
  end
  return uint8(nmax)
end


