using FluentValidation;
using MediatR;
using Api.Models;
using Api.Repository;

namespace Api.Queries.UserDevicePinQuery;

public class GetActiveDevicesQuery : IRequest<List<UserDevicePinDto>>
{
    public int CompanyId { get; set; }
    public int? UserId { get; set; }

    public class GetActiveDevicesQueryHandler : IRequestHandler<GetActiveDevicesQuery, List<UserDevicePinDto>>
    {
        private readonly UserDevicePinRepository _repository;

        public GetActiveDevicesQueryHandler(UserDevicePinRepository repository)
        {
            _repository = repository;
        }

        public async Task<List<UserDevicePinDto>> Handle(GetActiveDevicesQuery request, CancellationToken cancellationToken)
        {
            return await _repository.GetActiveDevicesAsync( request.UserId, request.CompanyId, cancellationToken);
        }
    }

    public class GetActiveDevicesQueryValidator : AbstractValidator<GetActiveDevicesQuery>
    {
        public GetActiveDevicesQueryValidator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0);
        }
    }
}