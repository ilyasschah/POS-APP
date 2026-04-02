using MediatR;
using FluentValidation;
using Api.Models;
using Api.Services;

namespace Api.Queries.FloorPlanQuery
{
    public class GetAllFloorPlansQuery : IRequest<List<FloorPlanDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllFloorPlansQueryHandler : IRequestHandler<GetAllFloorPlansQuery, List<FloorPlanDto>>
        {
            private readonly FloorPlanService _service;

            public GetAllFloorPlansQueryHandler(FloorPlanService service)
            {
                _service = service;
            }

            public async Task<List<FloorPlanDto>> Handle(GetAllFloorPlansQuery request, CancellationToken cancellationToken)
            {
                return await _service.GetAllAsync(request.CompanyId);
            }
        }
    }

    public class GetAllFloorPlansQueryValidator : AbstractValidator<GetAllFloorPlansQuery>
    {
        public GetAllFloorPlansQueryValidator()
        {
            RuleFor(x => x.CompanyId)
                .GreaterThan(0).WithMessage("CompanyId is required and must be greater than 0.");
        }
    }
}