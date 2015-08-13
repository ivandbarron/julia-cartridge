function juliaset(z, z0, nmax::Int64)
  for n = 1:nmax
    if abs(z) > 2
      return n-1
    end
  end
  return nmax
end