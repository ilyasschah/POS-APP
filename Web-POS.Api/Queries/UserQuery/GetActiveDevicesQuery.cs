using FluentValidation;
using MediatR;
using Api.Models;
using Api.DataBase;
using Microsoft.EntityFrameworkCore;

namespace Api.Queries.UserQuery;

public class GetActiveDevicesQuery : IRequest<List<UserDeviceDto>>
{
    public int UserId { get; set; }
    public int CompanyId { get; set; }

    public class GetActiveDevicesQueryHandler : IRequestHandler<GetActiveDevicesQuery, List<UserDeviceDto>>
    {
        private readonly AppDbContext _db;

        public GetActiveDevicesQueryHandler(AppDbContext db)
        {
            _db = db;
        }

        public async Task<List<UserDeviceDto>> Handle(GetActiveDevicesQuery request, CancellationToken cancellationToken)
        {
            return await _db.UserDevicePins
                .AsNoTracking()
                .Where(p => p.UserId == request.UserId && p.CompanyId == request.CompanyId)
                .Select(p => new UserDeviceDto
                {
                    DeviceId = p.DeviceId,
                    CreatedAt = p.CreatedAt
                })
                .ToListAsync(cancellationToken);
        }
    }

    public class GetActiveDevicesQueryValidator : AbstractValidator<GetActiveDevicesQuery>
    {
        public GetActiveDevicesQueryValidator()
        {
            RuleFor(x => x.UserId).GreaterThan(0);
            RuleFor(x => x.CompanyId).GreaterThan(0);
        }
    }
}