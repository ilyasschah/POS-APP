using Api.Models;
using Api.Services;
using FluentValidation;
using MediatR;

namespace Api.Queries.SecurityKeysQuery
{
    public class GetAllSecurityKeysQuery : IRequest<List<SecurityKeyDto>>
    {
        public required int CompanyId { get; set; }
    }
    public class GetAllSecurityKeysHandler : IRequestHandler<GetAllSecurityKeysQuery, List<SecurityKeyDto>>
    {
        private readonly SecurityKeyService _service;

        public GetAllSecurityKeysHandler(SecurityKeyService service)
        {
            _service = service;
        }

        public async Task<List<SecurityKeyDto>> Handle(GetAllSecurityKeysQuery request, CancellationToken cancellationToken)
        {
            return await _service.GetAllAsync(request.CompanyId);
        }
    }
    public class GetAllSecurityKeysValidator : AbstractValidator<GetAllSecurityKeysQuery>
    {
        public GetAllSecurityKeysValidator()
        {
            RuleFor(q => q.CompanyId).GreaterThan(0).WithMessage("Company ID must be greater than 0.");
        }
    }
}