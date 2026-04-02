using MediatR;
using FluentValidation;
using Api.Models;
using Api.Services;

namespace Api.Queries.FloorPlanQuery
{
    public class GetFloorPlanByIdQuery : IRequest<FloorPlanDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public class GetFloorPlanByIdQueryHandler : IRequestHandler<GetFloorPlanByIdQuery, FloorPlanDto?>
        {
            private readonly FloorPlanService _service;

            public GetFloorPlanByIdQueryHandler(FloorPlanService service)
            {
                _service = service;
            }

            public async Task<FloorPlanDto?> Handle(GetFloorPlanByIdQuery request, CancellationToken cancellationToken)
            {
                return await _service.GetByIdAsync(request.Id, request.CompanyId);
            }
        }
    }

    public class GetFloorPlanByIdQueryValidator : AbstractValidator<GetFloorPlanByIdQuery>
    {
        public GetFloorPlanByIdQueryValidator()
        {
            RuleFor(x => x.Id)
                .GreaterThan(0).WithMessage("Id is required and must be greater than 0.");

            RuleFor(x => x.CompanyId)
                .GreaterThan(0).WithMessage("CompanyId is required and must be greater than 0.");
        }
    }
}